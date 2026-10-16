"""Wardrobe-item pipeline.

Unlike the digital twin, there is no person in these photos: the item is
photographed alone (flat lay, on a hanger, or on a mannequin). So there is no
pose check here, and since nothing else is in frame, rembg's own foreground
mask from background removal already is a correct outline of the item.
"""
import base64
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

import cv2
import numpy as np

from . import imaging
from .config import PIPELINE_VERSION, WARDROBE_CATEGORIES, Settings
from .engine import Engine
from .errors import BackgroundRemovalError, InvalidCategoryError, NoGarmentError
from .storage import WardrobeStore


@dataclass(frozen=True)
class WardrobeResult:
    item_id: str
    metadata: dict
    processed_jpg: bytes
    artifacts: dict[str, str]

    def to_response(self) -> dict:
        return {
            "success": True,
            "itemId": self.item_id,
            "metadata": self.metadata,
            "itemImageB64": base64.b64encode(self.processed_jpg).decode(),
        }


def _foreground_mask(rgba: np.ndarray) -> np.ndarray:
    """uint8 HxW mask, 255 where rembg kept the pixel (its alpha channel)."""
    if rgba.ndim < 3 or rgba.shape[2] != 4:
        # rembg should always return RGBA; don't crash on a surprise format.
        return np.full(rgba.shape[:2], 255, np.uint8)
    return (rgba[:, :, 3] > 127).astype(np.uint8) * 255


def create_wardrobe_item(
    raw: bytes,
    uid: str,
    category: str,
    *,
    engine: Engine,
    store: WardrobeStore,
    settings: Settings,
) -> WardrobeResult:
    """Upload bytes -> stored wardrobe item. Raises PipelineError subclasses."""
    if category not in WARDROBE_CATEGORIES:
        raise InvalidCategoryError(
            f"Unknown category {category!r}. Must be one of: {', '.join(sorted(WARDROBE_CATEGORIES))}."
        )

    imaging.validate_bytes(raw, settings.max_upload_bytes)
    original_ext = imaging.sniff_extension(raw)
    image = imaging.load_and_fix_orientation(raw, settings.max_pixels, settings.max_decode_side)
    imaging.validate_resolution(image, settings.min_short_side, settings.min_long_side)
    padded = imaging.resize_and_pad(image, settings.target_width, settings.target_height)

    cut_out = engine.remove_background(imaging.encode_png(padded))
    rgba = cv2.imdecode(np.frombuffer(cut_out, np.uint8), cv2.IMREAD_UNCHANGED)
    if rgba is None:
        raise BackgroundRemovalError("Failed to remove image background.")

    mask = _foreground_mask(rgba)
    fg_ratio = float((mask > 0).mean())
    if fg_ratio < settings.min_garment_foreground_ratio:
        raise NoGarmentError(
            "No clothing item detected in the photo. Please photograph the item "
            "alone, filling most of the frame, on a plain background."
        )

    rgba[:, :, :3] = imaging.enhance_quality(rgba[:, :, :3])
    item = imaging.composite_on_white(rgba)
    item_id = uuid.uuid4().hex
    processed_jpg = imaging.encode_jpeg(item)

    metadata = {
        "itemId": item_id,
        "uid": uid,
        "category": category,
        "status": "ready",
        "foregroundRatio": round(fg_ratio, 4),
        "imageWidth": settings.target_width,
        "imageHeight": settings.target_height,
        "pipelineVersion": PIPELINE_VERSION,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    # No separate mask is stored: the whole processed image IS the garment.
    artifacts = store.save(
        uid, item_id,
        original=raw, original_ext=original_ext,
        processed_jpg=processed_jpg, mask_png=None,
        metadata=metadata,
    )
    return WardrobeResult(item_id, metadata, processed_jpg, artifacts)
