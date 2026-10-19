import os
from dataclasses import dataclass
from pathlib import Path

PIPELINE_VERSION = "twin-0.6.0"

# Fixed vocab for wardrobe items (see app/wardrobe.py). Must match the
# mobile_app UI's closet categories (home_screen.dart's _categoryOrder)
# exactly, since the client sends these strings verbatim and they're stored
# as-is in Firestore/metadata. "Hijab" has no closet button yet but stays
# supported for the hijab-specific style/mask logic below. Style detection is
# not built: the client must ask the user and send one of HIJAB_STYLES.
WARDROBE_CATEGORIES = {"Tops", "Pants", "Skirts", "Shoes", "Accessories", "Hijab"}
HIJAB_STYLES = {"shawl", "pashmina", "instant", "khimar"}


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
    # Product-only wardrobe images can be square and smaller than a full-body
    # twin. The bundled catalog includes clean 360px product cutouts.
    min_garment_side: int = 256
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
    # Local FASHN VTON is the only clothing engine.
    fashn_worker_url: str = "http://127.0.0.1:8002"
    # FASHN VTON v1.5 does not support footwear or accessories. These use
    # FASHN's hosted Try-On Max endpoint when this server-side key is set.
    # Never place this key in the Flutter app.
    fashn_api_key: str = ""
    fashn_api_url: str = "https://api.fashn.ai/v1"
    tryon_worker_timeout_seconds: int = 1200
    # Allows the Flutter web build (served from its own dev-server origin) to
    # call this API. Fine while everything runs on one developer's machine;
    # narrow this to real origins before any deployment.
    cors_allow_all: bool = True


def get_settings() -> Settings:
    return Settings(
        data_dir=Path(os.getenv("AI_DATA_DIR", "data")),
        auth_disabled=os.getenv("AUTH_DISABLED", "0") == "1",
        firebase_project_id=os.getenv(
            "FIREBASE_PROJECT_ID", "stylesync-app-3d7c1"
        ),
        fashn_worker_url=os.getenv(
            "FASHN_WORKER_URL", "http://127.0.0.1:8002"
        ).rstrip("/"),
        fashn_api_key=os.getenv("FASHN_API_KEY", "").strip(),
        fashn_api_url=os.getenv(
            "FASHN_API_URL", "https://api.fashn.ai/v1"
        ).rstrip("/"),
        tryon_worker_timeout_seconds=int(
            os.getenv("TRYON_WORKER_TIMEOUT_SECONDS", "1200")
        ),
        cors_allow_all=os.getenv("CORS_ALLOW_ALL", "1") == "1",
    )
