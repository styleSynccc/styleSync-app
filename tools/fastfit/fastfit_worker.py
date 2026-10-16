"""FastFit as a small HTTP worker for apps/ai_service.

FastFit needs its own Python environment (torch + CUDA), separate from
ai_service's, so ai_service calls this over HTTP instead of importing it
(see FastFitTryOnEngine in apps/ai_service/app/tryon.py).

Run with FastFit's venv (FastFit cloned next to this repo, see SETUP.md):
  ..\\FastFit\\.venv\\Scripts\\python.exe tools\\fastfit\\fastfit_worker.py

POST /generate  (multipart)
  person:   person photo (any size; padded to 3:4 with white)
  garment:  one garment photo
  category: upper | lower | shoe
-> image/jpeg, same aspect ratio as `person`
"""
import io
import os
import sys
import threading
from pathlib import Path

FASTFIT_DIR = Path(
    os.environ.get("FASTFIT_DIR", Path(__file__).resolve().parents[3] / "FastFit")
)
# FastFit loads its models from relative paths (Models/...).
os.chdir(FASTFIT_DIR)
sys.path.insert(0, str(FASTFIT_DIR))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import uvicorn  # noqa: E402
from fastapi import FastAPI, File, Form, HTTPException, UploadFile  # noqa: E402
from fastapi.responses import Response  # noqa: E402
from PIL import Image  # noqa: E402

from app import FastFitDemo  # noqa: E402
from stylesync_tryon import crop_to_ratio, pad_to_fastfit  # noqa: E402

CATEGORY_ARGS = {"upper": "upper_img", "lower": "lower_img", "shoe": "shoe_img"}
GEN_SETTINGS = dict(
    ref_height=512, num_inference_steps=30, guidance_scale=2.5,
    use_square_mask=False, seed=42, enable_pose=True,
)

demo = FastFitDemo()
gpu_lock = threading.Lock()  # one generation at a time on a 6GB GPU
api = FastAPI(title="FastFit worker")


@api.get("/health")
def health():
    return {"status": "FastFit worker is running"}


@api.post("/generate")
def generate(
    person: UploadFile = File(...),
    garment: UploadFile = File(...),
    category: str = Form(...),
):
    if category not in CATEGORY_ARGS:
        raise HTTPException(400, f"category must be one of {sorted(CATEGORY_ARGS)}")
    try:
        person_img = Image.open(io.BytesIO(person.file.read()))
        garment_img = Image.open(io.BytesIO(garment.file.read())).convert("RGB")
    except Exception:
        raise HTTPException(400, "person and garment must be images")

    ratio = person_img.width / person_img.height
    garments = {"upper_img": None, "lower_img": None, "dress_img": None,
                "shoe_img": None, "bag_img": None}
    garments[CATEGORY_ARGS[category]] = garment_img
    with gpu_lock:
        image, message = demo.generate_image(pad_to_fastfit(person_img), **garments, **GEN_SETTINGS)
    if image is None:
        raise HTTPException(500, f"FastFit failed: {message}")

    out = io.BytesIO()
    crop_to_ratio(image, ratio).save(out, format="JPEG", quality=95)
    return Response(out.getvalue(), media_type="image/jpeg")


if __name__ == "__main__":
    uvicorn.run(api, host="127.0.0.1", port=int(os.environ.get("FASTFIT_PORT", 7861)))
