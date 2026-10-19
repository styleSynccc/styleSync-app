"""Transfer an outfit reference to a user-owned saved twin."""
import uuid
from datetime import datetime, timezone

import cv2

from . import imaging
from .config import Settings
from .errors import ImageValidationError, TryOnUnavailableError
from .storage import ResultStore, TwinStore
from .tryon import TryOnResult


def create_inspo(uid: str, twin_id: str, reference: bytes, *, twin_store: TwinStore,
                 result_store: ResultStore, inspo_engine, settings: Settings) -> TryOnResult:
    # Ownership is enforced by loading from this authenticated user's namespace.
    if not twin_id or len(twin_id) > 128 or any(c not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" for c in twin_id):
        raise ImageValidationError("Please select a valid saved twin.")
    twin = twin_store.load(uid, twin_id)
    imaging.validate_bytes(reference, settings.max_upload_bytes)
    inspiration = imaging.load_and_fix_orientation(
        reference, settings.max_pixels, settings.max_decode_side,
    )
    imaging.validate_resolution(inspiration, settings.min_short_side, settings.min_long_side)
    person = imaging.load_and_fix_orientation(twin.processed_jpg, settings.max_pixels)
    result = inspo_engine.apply_outfit(person, inspiration)
    ok, encoded = cv2.imencode(".jpg", result)
    if not ok:
        raise TryOnUnavailableError("Could not prepare your generated outfit.")
    result_id = uuid.uuid4().hex
    metadata = {
        "resultId": result_id, "uid": uid, "twinId": twin_id,
        "source": "inspo", "engine": inspo_engine.name,
        "resolution": "1k", "generationMode": "balanced",
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    jpg = encoded.tobytes()
    artifacts = result_store.save(uid, result_id, result_jpg=jpg, metadata=metadata)
    return TryOnResult(result_id, metadata, jpg, artifacts)
