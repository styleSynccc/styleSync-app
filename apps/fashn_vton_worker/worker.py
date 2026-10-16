"""Local HTTP worker for FASHN VTON v1.5.

It lives in an isolated environment so its current PyTorch/ONNX dependencies
cannot conflict with the main StyleSync image service or CatVTON.
"""

import io
import logging
import os
import sys
import threading
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image

os.environ.setdefault("HF_HUB_DOWNLOAD_TIMEOUT", "120")
os.environ.setdefault("HF_HUB_ETAG_TIMEOUT", "30")

LOGGER = logging.getLogger(__name__)
ROOT = Path(__file__).resolve().parents[2]
FASHN_REPO = Path(
    os.getenv("FASHN_VTON_REPO", ROOT / "third_party" / "fashn-vton-1.5")
).resolve()
WEIGHTS_DIR = Path(
    os.getenv("FASHN_VTON_WEIGHTS", FASHN_REPO / "weights")
).resolve()


class FashnRunner:
    def __init__(self) -> None:
        # Upstream describes 20 as the fast preset and 30 as balanced. Twenty
        # keeps requests within a practical local-development timeout; use the
        # environment variable to opt into the slower quality preset.
        self.steps = int(os.getenv("FASHN_VTON_STEPS", "20"))
        self.guidance_scale = float(os.getenv("FASHN_VTON_GUIDANCE_SCALE", "1.5"))
        self._pipeline = None
        self._torch = None
        self._load_lock = threading.Lock()
        self._inference_lock = threading.Lock()

    @property
    def loaded(self) -> bool:
        return self._pipeline is not None

    def _load(self):
        if self._pipeline is not None:
            return self._pipeline
        with self._load_lock:
            if self._pipeline is not None:
                return self._pipeline
            if not FASHN_REPO.joinpath("src", "fashn_vton", "pipeline.py").exists():
                raise RuntimeError(
                    "FASHN VTON source is missing. Run "
                    "apps/fashn_vton_worker/setup.ps1 first."
                )
            if not WEIGHTS_DIR.joinpath("model.safetensors").exists():
                raise RuntimeError(
                    "FASHN VTON weights are missing. Run "
                    "apps/fashn_vton_worker/setup.ps1 first."
                )

            sys.path.insert(0, str(FASHN_REPO / "src"))
            import torch
            from fashn_vton import TryOnPipeline

            if not torch.cuda.is_available():
                raise RuntimeError("FASHN VTON requires an NVIDIA CUDA GPU.")

            self._torch = torch
            self._pipeline = TryOnPipeline(
                weights_dir=str(WEIGHTS_DIR),
                device="cuda",
            )
            return self._pipeline

    def generate(
        self,
        person: Image.Image,
        garment: Image.Image,
        category: str,
        garment_photo_type: str,
        seed: int,
    ) -> Image.Image:
        pipeline = self._load()
        torch = self._torch
        assert torch is not None
        try:
            with self._inference_lock:
                output = pipeline(
                    person_image=person.convert("RGB"),
                    garment_image=garment.convert("RGB"),
                    category=category,
                    garment_photo_type=garment_photo_type,
                    num_samples=1,
                    num_timesteps=self.steps,
                    guidance_scale=self.guidance_scale,
                    seed=seed,
                    segmentation_free=True,
                )
                return output.images[0].convert("RGB")
        except torch.cuda.OutOfMemoryError as exc:
            torch.cuda.empty_cache()
            raise MemoryError(
                "FASHN VTON ran out of GPU memory. Close GPU-heavy programs. "
                "If it still fails, switch the StyleSync API to CatVTON."
            ) from exc
        finally:
            torch.cuda.empty_cache()


def _open_image(raw: bytes) -> Image.Image:
    try:
        image = Image.open(io.BytesIO(raw))
        image.load()
        return image.convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid image input.") from exc


runner = FashnRunner()
app = FastAPI(title="StyleSync FASHN VTON v1.5 worker")


@app.get("/health")
def health():
    return {
        "status": "ready" if runner.loaded else "not_loaded",
        "model": "FASHN VTON v1.5",
        "steps": runner.steps,
    }


@app.post("/generate")
async def generate(
    person: UploadFile = File(...),
    garment: UploadFile = File(...),
    category: str = Form(...),
    garment_photo_type: str = Form("flat-lay"),
    seed: int = Form(42),
):
    if category not in {"tops", "bottoms", "one-pieces"}:
        raise HTTPException(status_code=400, detail="Unsupported garment category.")
    if garment_photo_type not in {"model", "flat-lay"}:
        raise HTTPException(status_code=400, detail="Unsupported garment photo type.")

    person_image = _open_image(await person.read())
    garment_image = _open_image(await garment.read())
    try:
        result = runner.generate(
            person_image,
            garment_image,
            category,
            garment_photo_type,
            seed,
        )
    except MemoryError as exc:
        raise HTTPException(status_code=507, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        LOGGER.exception("FASHN VTON failed while loading or running inference")
        raise HTTPException(
            status_code=503,
            detail="FASHN VTON could not load or run. Check the worker terminal.",
        ) from exc

    output = io.BytesIO()
    result.save(output, format="JPEG", quality=94, optimize=True)
    return Response(content=output.getvalue(), media_type="image/jpeg")
