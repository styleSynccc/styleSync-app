"""Extract clothing worn by a person using the local worker's human parser."""

import cv2
import numpy as np
import requests

from .errors import GarmentExtractionError, NoGarmentError
from .imaging import encode_png


class GarmentExtractor:
    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")

    def mask(self, image: np.ndarray, category: str) -> np.ndarray | None:
        try:
            response = requests.post(
                f"{self.base_url}/extract-garment",
                files={"image": ("image.png", encode_png(image), "image/png")},
                data={"category": category},
                timeout=150,
            )
        except requests.RequestException as exc:
            raise GarmentExtractionError(
                "Could not isolate your clothing. Make sure the FASHN worker "
                "is running, then try again."
            ) from exc
        if response.status_code == 204:
            return None  # No person detected: use ordinary background removal.
        if response.status_code == 422:
            raise NoGarmentError(
                f"Could not find {category.lower()} in this photo. Choose a clearer "
                "photo where the whole garment is visible."
            )
        if not response.ok:
            raise GarmentExtractionError(
                "Clothing detection is unavailable. Please try again when the "
                "FASHN worker is ready."
            )
        mask = cv2.imdecode(np.frombuffer(response.content, np.uint8), cv2.IMREAD_GRAYSCALE)
        if mask is None or mask.shape != image.shape[:2]:
            raise GarmentExtractionError("Clothing detection returned an invalid mask. Please try again.")
        return (mask > 127).astype(np.uint8) * 255
