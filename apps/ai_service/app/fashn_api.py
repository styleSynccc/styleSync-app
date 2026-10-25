"""Hosted Try-On Max Quality 1K, one paid request per item or outfit reference."""

import base64
import time

import cv2
import numpy as np
import requests

from .errors import TryOnUnavailableError
from .config import MAX_TRYON_RESOLUTION, MAX_TRYON_MODE, MAX_TRYON_CREDITS


class FashnApiTryOnEngine:
    """All clothing, shoe/accessory placement and whole-outfit generation."""

    name = "fashn-tryon-max"
    resolution = MAX_TRYON_RESOLUTION
    generation_mode = MAX_TRYON_MODE
    credits_per_image = MAX_TRYON_CREDITS
    preserves_output_resolution = True

    def __init__(
        self,
        api_key: str,
        base_url: str = "https://api.fashn.ai/v1",
        timeout_seconds: int = 1200,
        poll_interval_seconds: float = 2.0,
    ):
        self.api_key = api_key.strip()
        self.base_url = base_url.rstrip("/")
        self.timeout_seconds = timeout_seconds
        self.poll_interval_seconds = poll_interval_seconds

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    def apply_hijab(self, person_bgr, hijab_bgr, hijab_mask):
        raise TryOnUnavailableError(
            "Hijab replacement is not enabled in StyleSync yet."
        )

    def apply_garment(
        self,
        person_bgr: np.ndarray,
        garment_bgr: np.ndarray,
        category: str,
        replace_mask: np.ndarray,
    ) -> np.ndarray:
        del replace_mask  # Try-On Max locates and places the product itself.
        if category == "Accessories":
            return self._generate(
                person_bgr, garment_bgr,
                "Add only the referenced fashion accessory to the person, worn or "
                "carried naturally in its appropriate location. For hats use the head, "
                "glasses the face, jewelry the appropriate ear, neck, wrist or finger, "
                "and bags the hand or shoulder. Match its design, color and size "
                "proportions. Preserve the person's identity, facial features, pose, "
                "body, existing clothes, shoes, other already-worn accessories, "
                "head covering and background. "
                "If the reference shows a person, transfer only the accessory.",
                generation_mode=self.generation_mode,
            )
        clothing = {
            "Tops": "Replace only the person's top with the referenced top. Preserve the existing bottoms, shoes and accessories.",
            "Pants": "Replace only the person's bottoms with the referenced pants. Preserve the existing top, shoes and accessories.",
            "Skirts": "Replace only the person's bottoms with the referenced skirt, including its waistband, length and hem. Preserve the existing top, shoes and accessories.",
        }
        if category in clothing:
            return self._generate(
                person_bgr, garment_bgr,
                clothing[category] + " Match the product's design, color, texture, "
                "patterns, fit and sleeve or leg length. Preserve the person's face, "
                "identity, body proportions, pose, existing hijab or head covering "
                "and background. Do not expose hair or neck covered in model_image. "
                "If the reference shows a person, transfer only the selected garment, "
                "not their face, body or other clothes.",
                generation_mode=self.generation_mode,
            )
        if category != "Shoes":
            raise TryOnUnavailableError(
                "Choose Tops, Pants, Skirts, Shoes or Accessories."
            )
        return self._generate(
            person_bgr, garment_bgr,
            "Put the referenced pair of shoes on the person's feet. "
            "Preserve their identity, pose, body, existing clothing, accessories, "
            "hijab or head covering, and background.",
            generation_mode=self.generation_mode,
        )

    def apply_outfit(self, person_bgr: np.ndarray, reference_bgr: np.ndarray) -> np.ndarray:
        """Transfer the reference outfit in one paid Quality 1K generation."""
        return self._generate(
            person_bgr, reference_bgr,
            "Dress the person in model_image in the complete visible outfit worn by "
            "the person in product_image, including the top, bottoms or dress, and "
            "visible footwear. Match the reference clothing colors, patterns, cut, "
            "and layering. Preserve the model_image person's face, identity, body "
            "proportions, pose, hair, existing head covering, and background. "
            "Do not expose hair or neck covered in model_image. "
            "Transfer clothing only, not the reference person's face or body. "
            "Do not invent items hidden or absent in the reference.",
            generation_mode=self.generation_mode,
        )

    def _generate(self, person_bgr, garment_bgr, prompt, *, generation_mode):
        if not self.configured:
            raise TryOnUnavailableError(
                "Try-On Max needs a FASHN API key. Set FASHN_API_KEY in the "
                "terminal that starts the StyleSync API, then restart it."
            )

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model_name": "tryon-max",
            "inputs": {
                "model_image": _data_uri(person_bgr),
                "product_image": _data_uri(garment_bgr),
                "prompt": prompt,
                "resolution": self.resolution,
                "generation_mode": generation_mode,
                "seed": 42,
                "num_images": 1,
                "output_format": "png",
                "return_base64": True,
            },
        }

        try:
            response = requests.post(
                f"{self.base_url}/run",
                headers=headers,
                json=payload,
                timeout=min(60, self.timeout_seconds),
            )
        except requests.RequestException as exc:
            raise TryOnUnavailableError(
                "Could not reach FASHN Try-On Max."
            ) from exc
        body = _response_json(response, "start try-on")
        prediction_id = body.get("id")
        if not isinstance(prediction_id, str) or not prediction_id:
            raise TryOnUnavailableError(
                "FASHN Try-On Max did not return a prediction ID."
            )

        deadline = time.monotonic() + self.timeout_seconds
        while time.monotonic() < deadline:
            if self.poll_interval_seconds > 0:
                time.sleep(self.poll_interval_seconds)
            try:
                response = requests.get(
                    f"{self.base_url}/status/{prediction_id}",
                    headers={"Authorization": f"Bearer {self.api_key}"},
                    timeout=min(60, self.timeout_seconds),
                )
            except requests.RequestException as exc:
                raise TryOnUnavailableError(
                    "Lost contact with FASHN while generating your outfit. Do not immediately retry; the request may still be processing."
                ) from exc
            status_body = _response_json(response, "check try-on")
            status = status_body.get("status")
            if status == "completed":
                return _decode_output(status_body)
            if status == "failed":
                error = status_body.get("error")
                if isinstance(error, dict):
                    detail = error.get("message") or error.get("name")
                else:
                    detail = error
                raise TryOnUnavailableError(
                    f"FASHN try-on failed: {detail or 'unknown provider error'}."
                )
            if status not in {"starting", "in_queue", "processing"}:
                raise TryOnUnavailableError(
                    f"FASHN returned an unexpected try-on status: {status!r}."
                )

        raise TryOnUnavailableError("FASHN try-on timed out. The request may still be processing; avoid immediately generating again.")


def _data_uri(image: np.ndarray) -> str:
    # Keep intermediate passes lossless. Dense PNGs can exceed FASHN's
    # per-input 30 MiB limit; fall back to high-quality JPEG without resizing.
    extension, mime = ".png", "image/png"
    ok, output = cv2.imencode(extension, image)
    if ok and output.nbytes > 30 * 1024 * 1024:
        extension, mime = ".jpg", "image/jpeg"
        ok, output = cv2.imencode(extension, image, [cv2.IMWRITE_JPEG_QUALITY, 98])
    if not ok:
        raise TryOnUnavailableError("Could not prepare an image for Try-On Max.")
    if output.nbytes > 30 * 1024 * 1024:
        raise TryOnUnavailableError("This image is too large for Try-On Max. Choose a simpler photo.")
    encoded = base64.b64encode(output.tobytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def _response_json(response: requests.Response, action: str) -> dict:
    try:
        body = response.json()
    except ValueError as exc:
        raise TryOnUnavailableError(
            f"FASHN sent an invalid response while trying to {action}."
        ) from exc
    if not isinstance(body, dict):
        raise TryOnUnavailableError(f"FASHN sent an invalid response while trying to {action}.")
    if not response.ok:
        detail = body.get("message") or body.get("error")
        if isinstance(detail, dict):
            detail = detail.get("message") or detail.get("name")
        raise TryOnUnavailableError(
            f"FASHN could not {action}: {detail or f'HTTP {response.status_code}'}."
        )
    if not isinstance(body, dict):
        raise TryOnUnavailableError(
            f"FASHN sent an invalid response while trying to {action}."
        )
    return body


def _decode_output(body: dict) -> np.ndarray:
    outputs = body.get("output")
    if not isinstance(outputs, list) or not outputs or not isinstance(outputs[0], str):
        raise TryOnUnavailableError("FASHN completed without a try-on image.")
    value = outputs[0]
    if not value.startswith("data:image/") or "," not in value:
        raise TryOnUnavailableError(
            "FASHN did not return the private inline try-on image requested."
        )
    try:
        raw = base64.b64decode(value.split(",", 1)[1], validate=True)
    except (ValueError, base64.binascii.Error) as exc:
        raise TryOnUnavailableError("FASHN returned a damaged try-on image.") from exc
    result = cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_COLOR)
    if result is None:
        raise TryOnUnavailableError("FASHN returned an unreadable try-on image.")
    # Preserve the provider's actual dimensions rather than stretching results.
    return result
