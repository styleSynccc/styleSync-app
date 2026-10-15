"""Run one real CatVTON generation against the local worker."""

import argparse
import io
from pathlib import Path

import requests
from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
PERSON = ROOT / "third_party/CatVTON/resource/demo/example/person/men/model_5.png"
TOP = (
    ROOT
    / "third_party/CatVTON/resource/demo/example/condition/upper/21514384_52353349_1000.jpg"
)
PANTS = ROOT / "apps/mobile_app/assets/images/pants/jeans_blue.png"
OUTPUT = Path(__file__).resolve().parent / "smoke_result.jpg"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", choices=("Tops", "Pants"), default="Tops")
    args = parser.parse_args()
    garment = TOP if args.category == "Tops" else PANTS

    with Image.open(PERSON) as person:
        width, height = person.size
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    if args.category == "Tops":
        draw.rounded_rectangle(
            (width * 0.20, height * 0.18, width * 0.80, height * 0.62),
            radius=max(8, width // 20),
            fill=255,
        )
    else:
        # Approximate the sample person's detected hip/knee/ankle landmarks.
        hips = ((width * 0.62, height * 0.68), (width * 0.42, height * 0.68))
        knees = ((width * 0.60, height * 0.98), (width * 0.35, height * 0.98))
        ankles = ((width * 0.60, height), (width * 0.30, height))
        leg_width = max(24, int(width * 0.09))
        draw.polygon((hips[0], hips[1], knees[1], knees[0]), fill=255)
        draw.line((hips[0], knees[0], ankles[0]), fill=255, width=leg_width)
        draw.line((hips[1], knees[1], ankles[1]), fill=255, width=leg_width)
    mask_bytes = io.BytesIO()
    mask.save(mask_bytes, format="PNG")

    with PERSON.open("rb") as person_file, garment.open("rb") as garment_file:
        response = requests.post(
            "http://127.0.0.1:8001/generate",
            files={
                "person": (PERSON.name, person_file, "image/png"),
                "garment": (garment.name, garment_file, "application/octet-stream"),
                "mask": ("mask.png", mask_bytes.getvalue(), "image/png"),
            },
            data={"category": args.category, "seed": "42"},
            timeout=1200,
        )
    response.raise_for_status()
    OUTPUT.write_bytes(response.content)
    print(f"Saved {OUTPUT} ({len(response.content)} bytes)")


if __name__ == "__main__":
    main()
