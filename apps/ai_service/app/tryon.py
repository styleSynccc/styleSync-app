"""Try-on orchestration for stored twins and wardrobe items.

The production default plugs the local CatVTON worker into ``TryOnEngine``;
tests can inject a deterministic engine without loading diffusion weights.
"""
import base64
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Protocol

import cv2
import numpy as np

from . import imaging
from .config import PIPELINE_VERSION, Settings
from .errors import (
    InvalidWardrobeItemError,
    TryOnNotImplementedError,
    TryOnUnavailableError,
)
from .storage import ResultStore, TwinStore, WardrobeStore
from .tryon_mask import clothing_mask

GARMENT_CATEGORIES = {"Tops", "Pants"}


class TryOnEngine(Protocol):
    name: str

    def apply_hijab(
        self, person_bgr: np.ndarray, hijab_bgr: np.ndarray, hijab_mask: np.ndarray | None
    ) -> tuple[np.ndarray, np.ndarray]:
        """(person now wearing the chosen hijab, mask of where it landed on
        THAT image). Stage 2 must protect the returned mask, not `hijab_mask`:
        the latter is in the flat-lay wardrobe photo's own coordinates, not
        the person's canvas, and using it directly would protect the wrong
        pixels."""
        ...

    def apply_garment(
        self,
        person_bgr: np.ndarray,
        garment_bgr: np.ndarray,
        category: str,
        replace_mask: np.ndarray,
    ) -> np.ndarray:
        """Person now wearing the chosen garment inside `replace_mask`."""
        ...


class NotImplementedTryOnEngine:
    """Placeholder until a real try-on model is wired in. Raises immediately -
    the orchestration around it (below) can be built and tested without
    pretending a generated image exists.
    """

    name = "none"

    def apply_hijab(self, person_bgr, hijab_bgr, hijab_mask):
        raise TryOnNotImplementedError(
            "Hijab try-on is not implemented yet. Needs a real try-on model (e.g. OOTDiffusion)."
        )

    def apply_garment(self, person_bgr, garment_bgr, category, replace_mask):
        raise TryOnNotImplementedError(
            "Clothing try-on is not implemented yet. Needs a real try-on model (e.g. OOTDiffusion)."
        )


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


def _decode(data: bytes, grayscale: bool = False) -> np.ndarray:
    flag = cv2.IMREAD_GRAYSCALE if grayscale else cv2.IMREAD_COLOR
    return cv2.imdecode(np.frombuffer(data, np.uint8), flag)


def create_tryon(
    uid: str,
    twin_id: str,
    garment_item_id: str,
    hijab_item_id: str | None,
    *,
    twin_store: TwinStore,
    wardrobe_store: WardrobeStore,
    tryon_engine: TryOnEngine,
    result_store: ResultStore,
    settings: Settings,
) -> TryOnResult:
    """Twin + garment (+ optional hijab) -> stored try-on result.

    hijab_item_id omitted means "keep the twin's own hijab" (per the workflow
    doc): if the twin photo has its own hijab_mask, that protects it during
    the clothing stage. hijab_item_id given means swap in a different hijab
    first, and protect wherever the engine places that one instead.

    Raises PipelineError subclasses.
    """
    twin = twin_store.load(uid, twin_id)
    garment = wardrobe_store.load(uid, garment_item_id)
    if garment.metadata.get("category") not in GARMENT_CATEGORIES:
        raise InvalidWardrobeItemError(
            f"{garment_item_id!r} is not a clothing item (category="
            f"{garment.metadata.get('category')!r}). garmentItemId must be one "
            f"of: {', '.join(sorted(GARMENT_CATEGORIES))}."
        )

    person = _decode(twin.processed_jpg)
    protect_mask = _decode(twin.hijab_mask_png, grayscale=True) if twin.hijab_mask_png else None

    if hijab_item_id is not None:
        hijab_item = wardrobe_store.load(uid, hijab_item_id)
        if hijab_item.metadata.get("category") != "Hijab":
            raise InvalidWardrobeItemError(f"{hijab_item_id!r} is not a hijab item.")
        hijab_bgr = _decode(hijab_item.processed_jpg)
        hijab_mask = _decode(hijab_item.mask_png, grayscale=True) if hijab_item.mask_png else None
        person, protect_mask = tryon_engine.apply_hijab(person, hijab_bgr, hijab_mask)

    garment_bgr = _decode(garment.processed_jpg)
    try:
        replace_mask = clothing_mask(
            person.shape[:2],
            twin.landmarks,
            garment.metadata["category"],
            protect_mask,
        )
    except (KeyError, TypeError, ValueError) as exc:
        raise TryOnUnavailableError(
            "This digital twin is missing pose data. Create a new digital twin and try again."
        ) from exc
    final = tryon_engine.apply_garment(
        person,
        garment_bgr,
        garment.metadata["category"],
        replace_mask,
    )

    result_id = uuid.uuid4().hex
    result_jpg = imaging.encode_jpeg(final)
    metadata = {
        "resultId": result_id,
        "uid": uid,
        "twinId": twin_id,
        "garmentItemId": garment_item_id,
        "hijabItemId": hijab_item_id,
        "status": "ready",
        "tryOnEngine": tryon_engine.name,
        "pipelineVersion": PIPELINE_VERSION,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    artifacts = result_store.save(uid, result_id, result_jpg=result_jpg, metadata=metadata)
    return TryOnResult(result_id, metadata, result_jpg, artifacts)
