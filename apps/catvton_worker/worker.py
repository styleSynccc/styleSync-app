"""Small local HTTP worker around the official CatVTON inference pipeline.

The worker intentionally lives in its own Python environment. CatVTON pins an
older PyTorch/diffusers stack that conflicts with StyleSync's image pipeline.
"""

import io
import logging
import os
import sys
import threading
from pathlib import Path

import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image, ImageFilter


# Hugging Face's default ten-second read timeout is too short for CatVTON's
# multi-gigabyte first-run download on many home connections. Partial files are
# cached, so an interrupted setup can safely resume on the next request.
os.environ.setdefault("HF_HUB_DOWNLOAD_TIMEOUT", "120")
os.environ.setdefault("HF_HUB_ETAG_TIMEOUT", "30")
os.environ.setdefault("HF_HUB_ENABLE_HF_TRANSFER", "1")

LOGGER = logging.getLogger(__name__)

ROOT = Path(__file__).resolve().parents[2]
CATVTON_REPO = Path(
    os.getenv("CATVTON_REPO", ROOT / "third_party" / "CatVTON")
).resolve()


class CatVTONRunner:
    def __init__(self) -> None:
        self.width = int(os.getenv("CATVTON_WIDTH", "384"))
        self.height = int(os.getenv("CATVTON_HEIGHT", "512"))
        self.steps = int(os.getenv("CATVTON_STEPS", "30"))
        self.guidance_scale = float(os.getenv("CATVTON_GUIDANCE_SCALE", "2.5"))
        self.base_model = os.getenv(
            "CATVTON_BASE_MODEL", "runwayml/stable-diffusion-inpainting"
        )
        self.checkpoint = os.getenv("CATVTON_CHECKPOINT", "zhengchong/CatVTON")
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
            if not CATVTON_REPO.joinpath("model", "pipeline.py").exists():
                raise RuntimeError(
                    "CatVTON source is missing. Run apps/catvton_worker/setup.ps1 first."
                )

            sys.path.insert(0, str(CATVTON_REPO))
            import torch
            from huggingface_hub import snapshot_download
            from model.pipeline import CatVTONPipeline

            if not torch.cuda.is_available():
                raise RuntimeError("CatVTON requires an NVIDIA CUDA GPU.")

            checkpoint_path = self.checkpoint
            if not Path(checkpoint_path).exists():
                # The upstream pipeline downloads the entire CatVTON repository,
                # including DensePose, SCHP and unused dataset-specific weights.
                # StyleSync supplies its own mask, so only the mixed attention
                # checkpoint is needed for inference.
                checkpoint_path = snapshot_download(
                    repo_id=self.checkpoint,
                    allow_patterns=["mix-48k-1024/attention/*"],
                )

            self._torch = torch
            self._pipeline = CatVTONPipeline(
                base_ckpt=self.base_model,
                attn_ckpt=checkpoint_path,
                attn_ckpt_version="mix",
                weight_dtype=torch.float16,
                device="cuda",
                skip_safety_check=True,
                use_tf32=True,
            )
            return self._pipeline

    def generate(
        self,
        person: Image.Image,
        garment: Image.Image,
        mask: Image.Image,
        seed: int,
    ) -> Image.Image:
        pipeline = self._load()
        torch = self._torch
        assert torch is not None

        person = person.convert("RGB")
        garment = garment.convert("RGB")
        mask = mask.convert("L")
        if person.size != mask.size:
            raise ValueError("The person and replacement mask must have the same size.")

        # A slightly softened mask prevents a visible hard seam at sleeves and waist.
        mask = mask.filter(ImageFilter.GaussianBlur(radius=4))
        generator = torch.Generator(device="cuda").manual_seed(seed)

        try:
            with self._inference_lock:
                result = pipeline(
                    image=person,
                    condition_image=garment,
                    mask=mask,
                    width=self.width,
                    height=self.height,
                    num_inference_steps=self.steps,
                    guidance_scale=self.guidance_scale,
                    generator=generator,
                )[0]
        except torch.cuda.OutOfMemoryError as exc:
            torch.cuda.empty_cache()
            raise MemoryError(
                "CatVTON ran out of GPU memory. Close GPU-heavy programs or lower "
                "CATVTON_WIDTH and CATVTON_HEIGHT."
            ) from exc
        finally:
            torch.cuda.empty_cache()

        # Repaint everything outside the requested clothing region with the
        # original person. This protects the face, hands, background and hijab.
        target_size = (self.width, self.height)
        original = _resize_and_crop(person, target_size)
        resized_mask = _resize_and_crop(mask, target_size)
        return Image.composite(result.convert("RGB"), original, resized_mask)


def _resize_and_crop(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    width, height = image.size
    target_width, target_height = size
    if width / height < target_width / target_height:
        new_width = width
        new_height = width * target_height // target_width
    else:
        new_height = height
        new_width = height * target_width // target_height
    cropped = image.crop(
        (
            (width - new_width) // 2,
            (height - new_height) // 2,
            (width + new_width) // 2,
            (height + new_height) // 2,
        )
    )
    return cropped.resize(size, Image.Resampling.LANCZOS)


def _open_image(raw: bytes, mode: str) -> Image.Image:
    try:
        image = Image.open(io.BytesIO(raw))
        image.load()
        return image.convert(mode)
    except Exception as exc:
        raise HTTPException(status_code=400, detail="Invalid image input.") from exc


runner = CatVTONRunner()
app = FastAPI(title="StyleSync CatVTON worker")


@app.get("/health")
def health():
    return {
        "status": "ready" if runner.loaded else "not_loaded",
        "model": "CatVTON",
        "width": runner.width,
        "height": runner.height,
    }


@app.post("/generate")
async def generate(
    person: UploadFile = File(...),
    garment: UploadFile = File(...),
    mask: UploadFile = File(...),
    category: str = Form(...),
    seed: int = Form(42),
):
    if category not in {"Tops", "Pants"}:
        raise HTTPException(
            status_code=400,
            detail="CatVTON currently supports Tops and Pants only.",
        )

    person_image = _open_image(await person.read(), "RGB")
    garment_image = _open_image(await garment.read(), "RGB")
    mask_image = _open_image(await mask.read(), "L")
    if not np.asarray(mask_image).any():
        raise HTTPException(status_code=400, detail="The clothing mask is empty.")

    try:
        result = runner.generate(person_image, garment_image, mask_image, seed)
    except MemoryError as exc:
        raise HTTPException(status_code=507, detail=str(exc)) from exc
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        LOGGER.exception("CatVTON failed while loading the model or running inference")
        raise HTTPException(
            status_code=503,
            detail=(
                "CatVTON could not load or run. If this is the first run, check "
                "the worker terminal and retry so the model download can resume."
            ),
        ) from exc

    output = io.BytesIO()
    result.save(output, format="JPEG", quality=92, optimize=True)
    return Response(content=output.getvalue(), media_type="image/jpeg")
