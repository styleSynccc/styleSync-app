"""Generate one real image through the local FASHN worker."""

import argparse
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]
FASHN = ROOT / "third_party" / "fashn-vton-1.5"
PERSON = FASHN / "examples" / "data" / "model.webp"
GARMENT = FASHN / "examples" / "data" / "garment.webp"
OUTPUT = Path(__file__).resolve().parent / "smoke_result.jpg"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:8002")
    args = parser.parse_args()
    with PERSON.open("rb") as person_file, GARMENT.open("rb") as garment_file:
        response = requests.post(
            f"{args.url.rstrip('/')}/generate",
            files={
                "person": (PERSON.name, person_file, "image/webp"),
                "garment": (GARMENT.name, garment_file, "image/webp"),
            },
            data={
                "category": "tops",
                "garment_photo_type": "model",
                "seed": "42",
            },
            timeout=1200,
        )
    response.raise_for_status()
    OUTPUT.write_bytes(response.content)
    print(f"Saved {OUTPUT} ({len(response.content)} bytes)")


if __name__ == "__main__":
    main()
