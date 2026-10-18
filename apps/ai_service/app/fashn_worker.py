"""HTTP adapter from StyleSync to the local FASHN VTON v1.5 worker."""

import cv2
import numpy as np
import requests

from .errors import TryOnUnavailableError


class FashnWorkerTryOnEngine:

    _CATEGORY_MAP = {"Tops": "tops", "Pants": "bottoms", "Skirts": "bottoms"}

    def __init__(self, base_url: str, timeout_seconds: int = 600, shoe_engine=None):
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.shoe_engine = shoe_engine
        self.name = (
            "fashn-vton-1.5+fashn-tryon-max"
            if shoe_engine is not None and shoe_engine.configured
            else "fashn-vton-1.5"
        )

    def apply_hijab(self, person_bgr, hijab_bgr, hijab_mask):
        raise TryOnUnavailableError(
            "Hijab replacement is not supported by FASHN VTON yet."
        )

    def apply_garment(
        self,
        person_bgr: np.ndarray,
        garment_bgr: np.ndarray,
        category: str,
        replace_mask: np.ndarray,
    ) -> np.ndarray:
        if category == "Shoes":
            if self.shoe_engine is None:
                raise TryOnUnavailableError(
                    "Shoe try-on needs the hosted FASHN Try-On Max engine."
                )
            return self.shoe_engine.apply_garment(
                person_bgr,
                garment_bgr,
                category,
                replace_mask,
            )
        del replace_mask  # Local FASHN performs its own maskless human parsing.
        model_category = self._CATEGORY_MAP.get(category)
        if model_category is None:
            raise TryOnUnavailableError(
                "FASHN VTON currently supports Tops, Pants, Skirts, and configured Shoes only."
            )

        files = {
            "person": ("person.jpg", _encode(".jpg", person_bgr), "image/jpeg"),
            "garment": ("garment.jpg", _encode(".jpg", garment_bgr), "image/jpeg"),
        }
        try:
            response = requests.post(
                f"{self.base_url}/generate",
                files=files,
                data={
                    "category": model_category,
                    "garment_photo_type": "flat-lay",
                    # A skirt changes the silhouette. Hide the original
                    # bottoms so the model does not simply retain the pants.
                    "segmentation_free": "false" if category == "Skirts" else "true",
                    **({"num_timesteps": "30", "guidance_scale": "3.0", "verify_skirt": "true"}
                       if category == "Skirts" else {}),
                    "seed": "7" if category == "Skirts" else "42",
                },
                timeout=self.timeout_seconds,
            )
        except requests.RequestException as exc:
            raise TryOnUnavailableError(
                "The FASHN VTON worker is not running. Start "
                "apps/fashn_vton_worker/start.ps1 and try again."
            ) from exc

        if not response.ok:
            try:
                detail = response.json().get("detail")
            except ValueError:
                detail = None
            raise TryOnUnavailableError(
                detail or f"FASHN VTON failed with HTTP {response.status_code}."
            )

        result = cv2.imdecode(
            np.frombuffer(response.content, np.uint8), cv2.IMREAD_COLOR
        )
        if result is None:
            raise TryOnUnavailableError("FASHN VTON returned an invalid result image.")
        return cv2.resize(
            result,
            (person_bgr.shape[1], person_bgr.shape[0]),
            interpolation=cv2.INTER_LANCZOS4,
        )


def _encode(extension: str, image: np.ndarray) -> bytes:
    ok, output = cv2.imencode(extension, image)
    if not ok:
        raise TryOnUnavailableError("Could not prepare an image for FASHN VTON.")
    return output.tobytes()
