import threading
from typing import Protocol, Sequence

import cv2
import numpy as np

from .config import Settings
from .pose import Landmark


class Engine(Protocol):
    """The two heavy model calls. Faked in tests."""

    def detect_pose(self, image_bgr: np.ndarray) -> Sequence[Landmark] | None: ...

    def remove_background(self, png_bytes: bytes) -> bytes: ...


class ModelEngine:
    """MediaPipe pose + rembg, loaded once at startup."""

    def __init__(self, settings: Settings):
        # Imported here so the rest of the package works without the models installed.
        import mediapipe as mp
        from rembg import new_session

        self._pose = mp.solutions.pose.Pose(static_image_mode=True, model_complexity=1)
        self._pose_lock = threading.Lock()  # a MediaPipe Pose instance is not thread-safe
        self._session = new_session(settings.rembg_model)

    def detect_pose(self, image_bgr: np.ndarray) -> Sequence[Landmark] | None:
        rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
        with self._pose_lock:
            results = self._pose.process(rgb)
        if not results.pose_landmarks:
            return None
        return [
            Landmark(p.x, p.y, p.z, p.visibility)
            for p in results.pose_landmarks.landmark
        ]

    def remove_background(self, png_bytes: bytes) -> bytes:
        from rembg import remove

        return remove(png_bytes, session=self._session)
