import os
from dataclasses import dataclass
from pathlib import Path

PIPELINE_VERSION = "twin-0.6.0"

# Fixed vocab for wardrobe items (see app/wardrobe.py). Must match the
# mobile_app UI's closet categories (home_screen.dart's _categoryOrder)
# exactly, since the client sends these strings verbatim and they're stored
# as-is in Firestore/metadata.
WARDROBE_CATEGORIES = {"Tops", "Pants", "Shoes", "Accessories"}

# Wardrobe categories virtual try-on can put on, and the FastFit garment slot
# each one maps to. FastFit has no slot for accessories (watches, belts...),
# so those stay wardrobe-only.
TRYON_CATEGORIES = {"Tops": "upper", "Pants": "lower", "Shoes": "shoe"}


@dataclass(frozen=True)
class Settings:
    # Budget Samsung phones shoot 50 MP-class photos (roughly 8000x6000, 10-20 MB).
    max_upload_bytes: int = 25 * 1024 * 1024
    max_pixels: int = 100_000_000  # reject decompression bombs before decoding
    # Photos are downscaled to this long side while decoding; the pipeline works
    # at 768x1024 anyway, and a full 50 MP decode would use ~450 MB per request.
    max_decode_side: int = 3072
    # Below this the photo is upscaled too far for a sharp 768x1024 twin.
    min_short_side: int = 320
    min_long_side: int = 640
    # OOTDiffusion expects 3:4 portrait images
    target_width: int = 768
    target_height: int = 1024
    rembg_model: str = "isnet-general-use"
    # Below this share of the canvas, treat a wardrobe photo as empty/blank
    # rather than a real item. Not yet calibrated on real garment photos.
    min_garment_foreground_ratio: float = 0.02
    hijab_model_path: Path = Path("data/models/selfie_multiclass_256x256.tflite")
    data_dir: Path = Path("data")
    # Local development only. Never enable in a deployed environment.
    auth_disabled: bool = False
    # Used to validate the Firebase ID token audience and issuer. Token
    # verification uses Firebase's public signing certificates, so local
    # development does not need a service-account JSON file.
    firebase_project_id: str = "stylesync-app-3d7c1"
    # Allows the Flutter web build (served from its own dev-server origin) to
    # call this API. Fine while everything runs on one developer's machine;
    # narrow this to real origins before any deployment.
    cors_allow_all: bool = True
    # FastFit worker (tools/fastfit/fastfit_worker.py). None means try-on
    # isn't wired up and /v1/tryon answers 501.
    fastfit_url: str | None = None
    # One FastFit generation takes 20-60s on a laptop GPU; leave headroom.
    fastfit_timeout_s: float = 170.0


def get_settings() -> Settings:
    return Settings(
        data_dir=Path(os.getenv("AI_DATA_DIR", "data")),
        auth_disabled=os.getenv("AUTH_DISABLED", "0") == "1",
        firebase_project_id=os.getenv(
            "FIREBASE_PROJECT_ID", "stylesync-app-3d7c1"
        ),
        cors_allow_all=os.getenv("CORS_ALLOW_ALL", "1") == "1",
        fastfit_url=os.getenv("FASTFIT_URL", "http://127.0.0.1:7861") or None,
    )
