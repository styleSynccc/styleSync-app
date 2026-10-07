from dataclasses import dataclass
from typing import Protocol, Sequence

import numpy as np

from .pose import Landmark


@dataclass(frozen=True)
class HijabResult:
    wears_hijab: bool | None  # None = analyzer could not decide / not available
    confidence: float | None = None
    mask: np.ndarray | None = None  # uint8 HxW, 255 = hijab, same size as the twin image


class HijabAnalyzer(Protocol):
    name: str

    def analyze(self, image_bgr: np.ndarray, landmarks: Sequence[Landmark]) -> HijabResult: ...


class NullHijabAnalyzer:
    """Placeholder until the trained segmentation model exists.

    Reports "unknown" so the twin is still saved, and metadata records that
    hijab analysis has not run for it.
    """

    name = "none"

    def analyze(self, image_bgr, landmarks) -> HijabResult:
        return HijabResult(wears_hijab=None)
