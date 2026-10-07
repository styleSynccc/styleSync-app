import base64
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

import cv2
import numpy as np

from . import imaging
from .config import PIPELINE_VERSION, Settings
from .engine import Engine
from .errors import BackgroundRemovalError, InvalidPostureError, NoBodyError
from .hijab import HijabAnalyzer
from .pose import validate_pose_for_tryon
from .storage import TwinStore


@dataclass(frozen=True)
class TwinResult:
    twin_id: str
    metadata: dict
    landmarks: list[dict]
    processed_jpg: bytes
    artifacts: dict[str, str]

    def to_response(self) -> dict:
        return {
            "success": True,
            "twinId": self.twin_id,
            "metadata": self.metadata,
            "landmarks": self.landmarks,
            "personImageB64": base64.b64encode(self.processed_jpg).decode(),
        }


def create_twin(
    raw: bytes,
    uid: str,
    *,
    engine: Engine,
    hijab_analyzer: HijabAnalyzer,
    store: TwinStore,
    settings: Settings,
) -> TwinResult:
    """Upload bytes -> stored digital twin. Raises PipelineError subclasses."""
    imaging.validate_bytes(raw, settings.max_upload_bytes)
    original_ext = imaging.sniff_extension(raw)
    image = imaging.load_and_fix_orientation(raw, settings.max_pixels, settings.max_decode_side)
    imaging.validate_resolution(image, settings.min_short_side, settings.min_long_side)
    padded = imaging.resize_and_pad(image, settings.target_width, settings.target_height)

    # Pose check runs before the expensive background removal.
    landmarks = engine.detect_pose(padded)
    if landmarks is None:
        raise NoBodyError("No human body detected. Please upload a clear full-body photograph.")
    check = validate_pose_for_tryon(landmarks)
    if not check.ok:
        raise InvalidPostureError(check.message, check.reason)

    cut_out = engine.remove_background(imaging.encode_png(padded))
    rgba = cv2.imdecode(np.frombuffer(cut_out, np.uint8), cv2.IMREAD_UNCHANGED)
    if rgba is None:
        raise BackgroundRemovalError("Failed to remove image background.")
    rgba[:, :, :3] = imaging.enhance_quality(rgba[:, :, :3])
    person = imaging.composite_on_white(rgba)

    # Hijab analysis runs on the padded photo: the mask must line up with
    # the twin image, and background removal may have clipped the fabric.
    hijab = hijab_analyzer.analyze(padded, landmarks)

    twin_id = uuid.uuid4().hex
    processed_jpg = imaging.encode_jpeg(person)
    landmark_dicts = [
        {"x": p.x, "y": p.y, "z": p.z, "visibility": p.visibility} for p in landmarks
    ]
    metadata = {
        "twinId": twin_id,
        "uid": uid,
        "status": "ready",
        "wearsHijab": hijab.wears_hijab,
        "hijabConfidence": hijab.confidence,
        "hijabAnalyzer": hijab_analyzer.name,
        "poseChecksSkipped": list(check.skipped),
        "imageWidth": settings.target_width,
        "imageHeight": settings.target_height,
        "pipelineVersion": PIPELINE_VERSION,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    artifacts = store.save(
        uid,
        twin_id,
        original=raw,
        original_ext=original_ext,
        processed_jpg=processed_jpg,
        landmarks=landmark_dicts,
        hijab_mask_png=imaging.encode_png(hijab.mask) if hijab.mask is not None else None,
        metadata=metadata,
    )
    return TwinResult(twin_id, metadata, landmark_dicts, processed_jpg, artifacts)
