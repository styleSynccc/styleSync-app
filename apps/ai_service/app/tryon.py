"""Try-on orchestration: put stored wardrobe items on a stored digital twin.

Clothes go on one item per request (docs/virtual-tryon/README.md): the first
request starts from the twin, and each later one starts from the previous
result (`start_from_result_id`), so earlier items stay on.

Image generation is done by FastFit, which runs as a separate worker process
in its own Python environment (tools/fastfit/fastfit_worker.py);
FastFitTryOnEngine calls it over HTTP. FastFit only knows tops, bottoms and
shoes here (TRYON_CATEGORIES); there is no hijab step.
"""
import base64
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Protocol

import cv2
import numpy as np
import requests

from . import imaging
from .config import PIPELINE_VERSION, TRYON_CATEGORIES, Settings
from .errors import (
    InvalidWardrobeItemError,
    TryOnEngineUnavailableError,
    TryOnFailedError,
    TryOnNotImplementedError,
)
from .storage import ResultStore, TwinStore, WardrobeStore


class TryOnEngine(Protocol):
    name: str

    def apply_garment(
        self, person_bgr: np.ndarray, garment_bgr: np.ndarray, category: str
    ) -> np.ndarray:
        """Person now wearing the chosen garment. `category` is one of
        TRYON_CATEGORIES; everything outside that garment's area should be
        left as it was."""
        ...


class NotImplementedTryOnEngine:
    """Used when no try-on engine is configured (no FastFit worker URL).
    Raises immediately, so the orchestration below can be built and tested
    without pretending a generated image exists.
    """

    name = "none"

    def apply_garment(self, person_bgr, garment_bgr, category):
        raise TryOnNotImplementedError(
            "Clothing try-on is not set up. Start the FastFit worker and set FASTFIT_URL."
        )


class FastFitTryOnEngine:
    """Calls the FastFit worker (tools/fastfit/fastfit_worker.py)."""

    name = "fastfit"

    def __init__(self, url: str, timeout_s: float):
        self._url = url.rstrip("/")
        self._timeout_s = timeout_s

    def apply_garment(self, person_bgr, garment_bgr, category):
        files = {
            "person": ("person.jpg", imaging.encode_jpeg(person_bgr), "image/jpeg"),
            "garment": ("garment.jpg", imaging.encode_jpeg(garment_bgr), "image/jpeg"),
        }
        try:
            response = requests.post(
                f"{self._url}/generate", files=files,
                data={"category": TRYON_CATEGORIES[category]},
                timeout=self._timeout_s,
            )
        except requests.ConnectionError:
            raise TryOnEngineUnavailableError(
                "The try-on engine isn't running. Start tools/fastfit/fastfit_worker.py."
            )
        except requests.Timeout:
            raise TryOnFailedError("Try-on took too long. Please try again.")
        if response.status_code != 200:
            raise TryOnFailedError(f"Try-on failed: {response.text[:200]}")

        out = _decode(response.content)
        if out is None:
            raise TryOnFailedError("Try-on engine sent back an unreadable image.")
        if out.shape[:2] != person_bgr.shape[:2]:
            out = cv2.resize(out, (person_bgr.shape[1], person_bgr.shape[0]),
                             interpolation=cv2.INTER_LANCZOS4)
        return out


@dataclass(frozen=True)
class TryOnResult:
    result_id: str
    metadata: dict
    result_jpg: bytes
    artifacts: dict[str, str]

    def to_response(self) -> dict:
        return {
            "success": True,
            "resultId": self.result_id,
            "metadata": self.metadata,
            "resultImageB64": base64.b64encode(self.result_jpg).decode(),
        }


def _decode(data: bytes) -> np.ndarray:
    return cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)


def create_tryon(
    uid: str,
    twin_id: str,
    garment_item_id: str,
    start_from_result_id: str | None = None,
    *,
    twin_store: TwinStore,
    wardrobe_store: WardrobeStore,
    tryon_engine: TryOnEngine,
    result_store: ResultStore,
    settings: Settings,
) -> TryOnResult:
    """Twin + one garment -> stored try-on result.

    start_from_result_id given means put the garment on top of that earlier
    result (same twin) instead of the bare twin.

    Raises PipelineError subclasses.
    """
    twin = twin_store.load(uid, twin_id)
    garment = wardrobe_store.load(uid, garment_item_id)
    category = garment.metadata.get("category")
    if category not in TRYON_CATEGORIES:
        raise InvalidWardrobeItemError(
            f"{category or 'This item'} can't be tried on yet. Virtual try-on "
            f"supports: {', '.join(TRYON_CATEGORIES)}."
        )

    wearing = []
    if start_from_result_id is not None:
        start_meta, start_jpg = result_store.load(uid, start_from_result_id)
        if start_meta.get("twinId") != twin_id:
            raise InvalidWardrobeItemError(
                "startFromResultId belongs to a different digital twin."
            )
        person = _decode(start_jpg)
        # A second item of the same category replaces the first.
        wearing = [w for w in start_meta.get("wearing", []) if w["category"] != category]
    else:
        person = _decode(twin.processed_jpg)

    final = tryon_engine.apply_garment(person, _decode(garment.processed_jpg), category)

    result_id = uuid.uuid4().hex
    result_jpg = imaging.encode_jpeg(final)
    metadata = {
        "resultId": result_id,
        "uid": uid,
        "twinId": twin_id,
        "garmentItemId": garment_item_id,
        "category": category,
        "startFromResultId": start_from_result_id,
        "wearing": [*wearing, {"itemId": garment_item_id, "category": category}],
        "status": "ready",
        "tryOnEngine": tryon_engine.name,
        "pipelineVersion": PIPELINE_VERSION,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    artifacts = result_store.save(uid, result_id, result_jpg=result_jpg, metadata=metadata)
    return TryOnResult(result_id, metadata, result_jpg, artifacts)
