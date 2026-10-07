"""Download the MediaPipe model used for hijab analysis (16 MB) into data/models/.

    python -m scripts.download_models
"""
import urllib.request

from app.config import get_settings

URL = (
    "https://storage.googleapis.com/mediapipe-models/image_segmenter/"
    "selfie_multiclass_256x256/float32/latest/selfie_multiclass_256x256.tflite"
)


def main() -> None:
    dest = get_settings().hijab_model_path
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {URL}\n  -> {dest}")
    urllib.request.urlretrieve(URL, dest)
    print(f"Done ({dest.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
