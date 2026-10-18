"""Local HTTP worker for FASHN VTON v1.5.

It lives in an isolated environment so its current PyTorch/ONNX dependencies
cannot conflict with the main StyleSync image service.
"""

import io
import logging
import os
import sys
import threading
from pathlib import Path

import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import Response
from PIL import Image

from garment_extraction import garment_mask

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
        segmentation_free: bool = True,
        num_timesteps: int | None = None,
        guidance_scale: float | None = None,
        verify_skirt: bool = False,
    ) -> Image.Image:
        pipeline = self._load()
        torch = self._torch
        assert torch is not None
        try:
            with self._inference_lock:
                for attempt in range(2 if verify_skirt else 1):
                    output = pipeline(
                        person_image=person.convert("RGB"),
                        garment_image=garment.convert("RGB"),
                        category=category,
                        garment_photo_type=garment_photo_type,
                        num_samples=1,
                        num_timesteps=num_timesteps or self.steps,
                        guidance_scale=guidance_scale if guidance_scale is not None else self.guidance_scale,
                        seed=seed + attempt,
                        segmentation_free=segmentation_free,
                    )
                    result = output.images[0].convert("RGB")
                    if not verify_skirt:
                        return result
                    mask = garment_mask(pipeline.hp_model.predict(result), "Skirts")
                    if mask is not None and np.count_nonzero(mask) >= max(16, mask.size * 0.002):
                        return result
                    LOGGER.warning("Skirt generation did not produce a detectable skirt (attempt %s)", attempt + 1)
                raise RuntimeError(
                    "The model could not reproduce this skirt reliably. Try a clearer "
                    "skirt photo with the full waistband and hem visible."
                )
        except torch.cuda.OutOfMemoryError as exc:
            torch.cuda.empty_cache()
            raise MemoryError(
                "FASHN VTON ran out of GPU memory. Close GPU-heavy programs. "
                "If it still fails, reduce other GPU usage and try again."
            ) from exc
        finally:
            torch.cuda.empty_cache()

    def extract_garment(self, image: Image.Image, category: str):
        pipeline = self._load()
        with self._inference_lock:
            labels = pipeline.hp_model.predict(image.convert("RGB"))
        return garment_mask(labels, category)


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
    segmentation_free: bool = Form(True),
    num_timesteps: int | None = Form(None, ge=10, le=50),
    guidance_scale: float | None = Form(None, ge=1.0, le=5.0),
    verify_skirt: bool = Form(False),
):
    if category not in {"tops", "bottoms", "one-pieces"}:
        raise HTTPException(status_code=400, detail="Unsupported garment category.")
    if garment_photo_type not in {"model", "flat-lay"}:
        raise HTTPException(status_code=400, detail="Unsupported garment photo type.")
    if verify_skirt and category != "bottoms":
        raise HTTPException(status_code=400, detail="Skirt validation requires bottoms.")

    person_image = _open_image(await person.read())
    garment_image = _open_image(await garment.read())
    try:
        result = await run_in_threadpool(
            runner.generate,
            person_image,
            garment_image,
            category,
            garment_photo_type,
            seed,
            segmentation_free,
            num_timesteps,
            guidance_scale,
            verify_skirt,
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


@app.post("/extract-garment")
async def extract_garment(image: UploadFile = File(...), category: str = Form(...)):
    if category not in {"Tops", "Pants", "Skirts"}:
        raise HTTPException(status_code=400, detail="Choose Tops, Pants, or Skirts.")
    photo = _open_image(await image.read())
    try:
        mask = await run_in_threadpool(runner.extract_garment, photo, category)
    except Exception as exc:
        LOGGER.exception("Garment extraction failed")
        raise HTTPException(status_code=503, detail="Clothing detection is unavailable.") from exc
    if mask is None:
        return Response(status_code=204)
    if np.count_nonzero(mask) < max(16, mask.size * 0.002):
        raise HTTPException(status_code=422, detail="The selected garment was not found.")
    output = io.BytesIO()
    Image.fromarray(mask).save(output, format="PNG")
    return Response(content=output.getvalue(), media_type="image/png")
