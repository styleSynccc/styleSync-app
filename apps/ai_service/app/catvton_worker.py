"""HTTP adapter from the StyleSync orchestration layer to CatVTON."""

import cv2
import numpy as np
import requests

from .errors import TryOnUnavailableError


class CatVTONWorkerTryOnEngine:
    name = "catvton"

    def __init__(self, base_url: str, timeout_seconds: int = 600):
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds

    def apply_hijab(self, person_bgr, hijab_bgr, hijab_mask):
        raise TryOnUnavailableError(
            "Hijab replacement is not supported by CatVTON yet."
        )

    def apply_garment(
        self,
        person_bgr: np.ndarray,
        garment_bgr: np.ndarray,
        category: str,
        replace_mask: np.ndarray,
    ) -> np.ndarray:
        files = {
            "person": ("person.jpg", _encode(".jpg", person_bgr), "image/jpeg"),
            "garment": ("garment.jpg", _encode(".jpg", garment_bgr), "image/jpeg"),
            "mask": ("mask.png", _encode(".png", replace_mask), "image/png"),
        }
        try:
            response = requests.post(
                f"{self.base_url}/generate",
                files=files,
                data={"category": category, "seed": "42"},
                timeout=self.timeout_seconds,
            )
        except requests.RequestException as exc:
            raise TryOnUnavailableError(
                "The CatVTON worker is not running. Start "
                "apps/catvton_worker/start.ps1 and try again."
            ) from exc

        if not response.ok:
            try:
                detail = response.json().get("detail")
            except ValueError:
                detail = None
            raise TryOnUnavailableError(
                detail or f"CatVTON failed with HTTP {response.status_code}."
            )

        result = cv2.imdecode(np.frombuffer(response.content, np.uint8), cv2.IMREAD_COLOR)
        if result is None:
            raise TryOnUnavailableError("CatVTON returned an invalid result image.")
        return cv2.resize(
            result,
            (person_bgr.shape[1], person_bgr.shape[0]),
            interpolation=cv2.INTER_LANCZOS4,
        )


def _encode(extension: str, image: np.ndarray) -> bytes:
    ok, output = cv2.imencode(extension, image)
    if not ok:
        raise TryOnUnavailableError("Could not prepare an image for CatVTON.")
    return output.tobytes()
