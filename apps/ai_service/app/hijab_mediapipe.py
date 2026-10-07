"""Baseline hijab detection and head-covering mask, no training required.

Uses MediaPipe's multiclass selfie segmenter on a head-and-shoulders crop. That
model has no "hijab" class, but on all 10 hijab photos tested it labelled the
hijab as *clothes* (never hair) and found no neck skin, while every non-hijab
photo (women 5.0-9.6% hair, men 1.9-2.3%) showed hair or neck skin.

Limits (see PRD): the mask is the clothing connected to the face, cut at the
shoulder line. It cannot tell hijab from a shirt of the same class, so it is a
"head and shoulder area" mask, not an exact fabric boundary. A trained model
replaces this via the HijabAnalyzer interface.
"""
import logging
import threading
from pathlib import Path
from typing import Sequence

import cv2
import numpy as np

from .config import Settings
from .hijab import HijabResult, NullHijabAnalyzer
from .pose import LEFT_SHOULDER, RIGHT_SHOULDER, Landmark

log = logging.getLogger(__name__)

NOSE = 0
BACKGROUND, HAIR, BODY_SKIN, FACE_SKIN, CLOTHES, OTHERS = range(6)

MIN_FACE_PCT = 0.5        # below this no face was found: undecided
MAX_HAIR_NECK_PCT = 1.0   # hair + neck-skin share of the crop. Hijab: 0.0-0.1, others: 2.9+
MASK_BELOW_SHOULDERS = 0.35  # mask stops this many shoulder-widths below the shoulder line


def head_crop_box(lm: Sequence[Landmark], width: int, height: int) -> tuple[int, int, int, int]:
    """(x0, y0, x1, y1) head-and-shoulders crop in canvas pixels."""
    sw = abs(lm[LEFT_SHOULDER].x - lm[RIGHT_SHOULDER].x) * width
    cx, ny = lm[NOSE].x * width, lm[NOSE].y * height
    return (
        int(max(0, cx - 1.4 * sw)), int(max(0, ny - 1.3 * sw)),
        int(min(width, cx + 1.4 * sw)), int(min(height, ny + 1.5 * sw)),
    )


def interpret_labels(
    labels: np.ndarray,
    box: tuple[int, int, int, int],
    canvas_shape: tuple[int, ...],
    lm: Sequence[Landmark],
) -> HijabResult:
    """Turn per-pixel class labels of the crop into a hijab decision and mask."""
    pct = lambda cls: float((labels == cls).mean() * 100)
    if pct(FACE_SKIN) < MIN_FACE_PCT:
        return HijabResult(wears_hijab=None)  # cannot see a face: no decision
    if pct(HAIR) + pct(BODY_SKIN) >= MAX_HAIR_NECK_PCT:
        return HijabResult(wears_hijab=False)

    x0, y0, x1, y1 = box
    face = (labels == FACE_SKIN).astype(np.uint8)
    cover = ((labels == CLOTHES) | (labels == OTHERS)).astype(np.uint8)
    k = max(3, int(0.12 * labels.shape[1])) | 1
    near_face = cv2.dilate(face, np.ones((k, k), np.uint8)) > 0

    _, components = cv2.connectedComponents(cover)
    ids = np.unique(components[near_face & (cover > 0)])
    ids = ids[ids != 0]
    if len(ids) == 0:
        return HijabResult(wears_hijab=True)

    mask = np.zeros(canvas_shape[:2], np.uint8)
    mask[y0:y1, x0:x1][np.isin(components, ids)] = 255

    height = canvas_shape[0]
    sw_px = abs(lm[LEFT_SHOULDER].x - lm[RIGHT_SHOULDER].x) * canvas_shape[1]
    shoulder_px = (lm[LEFT_SHOULDER].y + lm[RIGHT_SHOULDER].y) / 2 * height
    mask[int(shoulder_px + MASK_BELOW_SHOULDERS * sw_px):, :] = 0
    return HijabResult(wears_hijab=True, mask=mask if mask.any() else None)


class MediaPipeHijabAnalyzer:
    name = "mediapipe-multiclass-v1"

    def __init__(self, model_path: Path):
        import mediapipe as mp
        from mediapipe.tasks import python as mp_tasks
        from mediapipe.tasks.python import vision

        self._mp = mp
        # Model bytes, not a path: MediaPipe mangles Windows paths.
        self._segmenter = vision.ImageSegmenter.create_from_options(
            vision.ImageSegmenterOptions(
                base_options=mp_tasks.BaseOptions(model_asset_buffer=Path(model_path).read_bytes()),
                output_category_mask=True,
                running_mode=vision.RunningMode.IMAGE,
            )
        )
        self._lock = threading.Lock()

    def segment_labels(self, image_bgr: np.ndarray, landmarks: Sequence[Landmark]):
        """(class labels of the head crop, crop box), or None if the crop is degenerate."""
        h, w = image_bgr.shape[:2]
        box = head_crop_box(landmarks, w, h)
        x0, y0, x1, y1 = box
        if x1 - x0 < 8 or y1 - y0 < 8:
            return None
        crop = np.ascontiguousarray(cv2.cvtColor(image_bgr[y0:y1, x0:x1], cv2.COLOR_BGR2RGB))
        with self._lock:
            result = self._segmenter.segment(
                self._mp.Image(image_format=self._mp.ImageFormat.SRGB, data=crop)
            )
            return result.category_mask.numpy_view().copy(), box

    def analyze(self, image_bgr: np.ndarray, landmarks: Sequence[Landmark]) -> HijabResult:
        seg = self.segment_labels(image_bgr, landmarks)
        if seg is None:
            return HijabResult(wears_hijab=None)
        labels, box = seg
        return interpret_labels(labels, box, image_bgr.shape, landmarks)


def load_hijab_analyzer(settings: Settings):
    """The MediaPipe analyzer if its model file is present, else the placeholder."""
    path = settings.hijab_model_path
    if not path.exists():
        log.warning("Hijab model not found at %s; hijab analysis disabled "
                    "(run `python -m scripts.download_models`)", path)
        return NullHijabAnalyzer()
    return MediaPipeHijabAnalyzer(path)
