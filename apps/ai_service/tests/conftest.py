import cv2
import numpy as np
import pytest

from app.pose import Landmark


def standing_landmarks(**overrides) -> list[Landmark]:
    """A valid front-facing standing pose. Override by index name, e.g. l25=Landmark(...)."""
    lm = [Landmark(0.5, 0.5, 0.0, 1.0) for _ in range(33)]
    lm[0] = Landmark(0.50, 0.10, 0, 1.0)   # nose
    lm[11] = Landmark(0.40, 0.25, 0, 1.0)  # shoulders
    lm[12] = Landmark(0.60, 0.25, 0, 1.0)
    lm[15] = Landmark(0.35, 0.50, 0, 0.9)  # wrists
    lm[16] = Landmark(0.65, 0.50, 0, 0.9)
    lm[23] = Landmark(0.43, 0.50, 0, 1.0)  # hips (torso 0.25, shoulders 0.20 apart: ratio 0.8)
    lm[24] = Landmark(0.57, 0.50, 0, 1.0)
    lm[25] = Landmark(0.43, 0.80, 0, 1.0)  # knees
    lm[26] = Landmark(0.57, 0.80, 0, 1.0)
    for name, value in overrides.items():
        lm[int(name.lstrip("l"))] = value
    return lm


class FakeEngine:
    def __init__(self, landmarks=None):
        self.landmarks = landmarks
        self.bg_calls = 0

    def detect_pose(self, image_bgr):
        return self.landmarks

    def remove_background(self, png_bytes):
        self.bg_calls += 1
        decoded = cv2.imdecode(np.frombuffer(png_bytes, np.uint8), cv2.IMREAD_COLOR)
        rgba = np.dstack([decoded, np.full(decoded.shape[:2], 255, np.uint8)])
        ok, buf = cv2.imencode(".png", rgba)
        return buf.tobytes()


@pytest.fixture
def photo_bytes() -> bytes:
    """A 600x900 JPEG."""
    img = np.full((900, 600, 3), 120, np.uint8)
    ok, buf = cv2.imencode(".jpg", img)
    return buf.tobytes()
