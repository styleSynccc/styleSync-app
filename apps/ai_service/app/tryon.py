"""Try-on orchestration for stored twins and wardrobe items.

The production default uses hosted Try-On Max Quality 1K;
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
from .tryon_crop import crop_for_tryon, normalize_tryon_result
from .tryon_mask import clothing_mask
from .generation_cost import confirm_generation_cost

GARMENT_CATEGORIES = {"Tops", "Pants", "Skirts", "Shoes", "Accessories"}
CATEGORY_ORDER = {"Tops": 0, "Pants": 1, "Skirts": 1, "Shoes": 2, "Accessories": 3}
MAX_ACCESSORIES = 5


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
    garment_item_ids: str | list[str],
    hijab_item_id: str | None,
    *,
    twin_store: TwinStore,
    wardrobe_store: WardrobeStore,
    tryon_engine: TryOnEngine,
    result_store: ResultStore,
    settings: Settings,
    confirmed_credits: int | None = None,
) -> TryOnResult:
    """Twin + clothing and up to five accessories (+ optional hijab) -> result.

    hijab_item_id omitted means "keep the twin's own hijab" (per the workflow
    doc): if the twin photo has its own hijab_mask, that protects it during
    the clothing stage. hijab_item_id given means swap in a different hijab
    first, and protect wherever the engine places that one instead.

    Raises PipelineError subclasses.
    """
    if isinstance(garment_item_ids, str):
        garment_item_ids = [garment_item_ids]
    if not garment_item_ids:
        raise InvalidWardrobeItemError("Choose at least one clothing, shoe, or accessory item.")
    if len(garment_item_ids) > 3 + MAX_ACCESSORIES:
        raise InvalidWardrobeItemError(
            "Choose at most one Top, one Pants or Skirt, one Shoes item, and five Accessories."
        )
    if len(set(garment_item_ids)) != len(garment_item_ids):
        raise InvalidWardrobeItemError("The same wardrobe item cannot be selected twice.")

    twin = twin_store.load(uid, twin_id)
    garments = [wardrobe_store.load(uid, item_id) for item_id in garment_item_ids]
    categories = [garment.metadata.get("category") for garment in garments]
    for item_id, category in zip(garment_item_ids, categories):
        if category not in GARMENT_CATEGORIES:
            raise InvalidWardrobeItemError(
                f"{item_id!r} is not a clothing item (category={category!r}). "
                f"garmentItemIds must contain: {', '.join(sorted(GARMENT_CATEGORIES))}."
            )
    clothing_categories = [category for category in categories if category != "Accessories"]
    if len(set(clothing_categories)) != len(clothing_categories):
        raise InvalidWardrobeItemError("Choose at most one item from each clothing category.")
    if categories.count("Accessories") > MAX_ACCESSORIES:
        raise InvalidWardrobeItemError("Choose at most five accessories per outfit.")

    if "Pants" in categories and "Skirts" in categories:
        raise InvalidWardrobeItemError("Choose either Pants or Skirts for an outfit, not both.")

    estimated_credits = confirm_generation_cost(
        tryon_engine, len(garment_item_ids), confirmed_credits,
    )

    # Accessories run last to preserve the generated clothing and shoes.
    ordered = sorted(
        zip(garment_item_ids, garments),
        key=lambda pair: CATEGORY_ORDER[pair[1].metadata["category"]],
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

    replace_masks = []
    try:
        for _, garment in ordered:
            if garment.metadata["category"] == "Accessories":
                # Hosted placement locates accessories itself; a clothing mask
                # would exclude faces, hands, and other valid locations.
                replace_masks.append(np.zeros(person.shape[:2], np.uint8))
                continue
            replace_masks.append(
                clothing_mask(
                    person.shape[:2],
                    twin.landmarks,
                    garment.metadata["category"],
                    protect_mask,
                )
            )
    except (KeyError, TypeError, ValueError) as exc:
        raise TryOnUnavailableError(
            "This digital twin is missing pose data. Create a new digital twin and try again."
        ) from exc

    high_resolution = getattr(tryon_engine, "preserves_output_resolution", False)
    if "Accessories" in categories or high_resolution:
        # Keep headroom and space beside the hands for hats and bags.
        crop_box = (0, 0, person.shape[1], person.shape[0])
        cropped_masks = replace_masks
    else:
        person, first_mask, crop_box = crop_for_tryon(
            person, replace_masks[0], twin.landmarks,
        )
        x1, y1, x2, y2 = crop_box
        cropped_masks = [first_mask]
        cropped_masks.extend(mask[y1:y2, x1:x2] for mask in replace_masks[1:])

    final = person
    for (_, garment), replace_mask in zip(ordered, cropped_masks):
        garment_bgr = _decode(garment.processed_jpg)
        final = tryon_engine.apply_garment(
            final,
            garment_bgr,
            garment.metadata["category"],
            replace_mask,
        )
    if not high_resolution:
        final = normalize_tryon_result(
            final,
            settings.target_width,
            settings.target_height,
        )

    result_id = uuid.uuid4().hex
    result_jpg = imaging.encode_jpeg(final, quality=98)
    metadata = {
        "resultId": result_id,
        "uid": uid,
        "twinId": twin_id,
        # Keep the singular field for old result readers.
        "garmentItemId": ordered[0][0],
        "garmentItemIds": [item_id for item_id, _ in ordered],
        "topItemId": next(
            (item_id for item_id, item in ordered if item.metadata["category"] == "Tops"),
            None,
        ),
        "pantsItemId": next(
            (item_id for item_id, item in ordered if item.metadata["category"] == "Pants"),
            None,
        ),
        "skirtItemId": next(
            (item_id for item_id, item in ordered if item.metadata["category"] == "Skirts"),
            None,
        ),
        "shoesItemId": next(
            (item_id for item_id, item in ordered if item.metadata["category"] == "Shoes"),
            None,
        ),
        "hijabItemId": hijab_item_id,
        "accessoryItemId": next(
            (item_id for item_id, item in ordered if item.metadata["category"] == "Accessories"),
            None,
        ),
        "accessoryItemIds": [
            item_id for item_id, item in ordered if item.metadata["category"] == "Accessories"
        ],
        "status": "ready",
        "tryOnEngine": tryon_engine.name,
        "resolution": getattr(tryon_engine, "resolution", "local"),
        "generationMode": getattr(tryon_engine, "generation_mode", "local"),
        "estimatedCredits": estimated_credits,
        "generationPasses": len(ordered),
        "imageWidth": final.shape[1],
        "imageHeight": final.shape[0],
        "personCrop": {
            "left": crop_box[0],
            "top": crop_box[1],
            "right": crop_box[2],
            "bottom": crop_box[3],
        },
        "pipelineVersion": PIPELINE_VERSION,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    artifacts = result_store.save(uid, result_id, result_jpg=result_jpg, metadata=metadata)
    return TryOnResult(result_id, metadata, result_jpg, artifacts)
