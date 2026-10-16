"""Crop excess canvas around a saved pose before virtual try-on."""

import cv2
import numpy as np


def crop_for_tryon(
    person: np.ndarray,
    replace_mask: np.ndarray,
    landmarks: list[dict],
    *,
    target_aspect: float = 3 / 4,
) -> tuple[np.ndarray, np.ndarray, tuple[int, int, int, int]]:
    """Return a portrait crop that keeps the full visible body in frame.

    Digital twins are stored on a fixed 768x1024 canvas. Phone photos with
    substantial empty margins can therefore make the person too small for a
    VTON model. The saved pose gives us a reliable, model-independent crop.
    """
    height, width = person.shape[:2]
    points = []
    for point in landmarks:
        try:
            visibility = float(point.get("visibility", 1.0))
            x = float(point["x"])
            y = float(point["y"])
        except (AttributeError, KeyError, TypeError, ValueError):
            continue
        if visibility >= 0.25 and -0.1 <= x <= 1.1 and -0.1 <= y <= 1.1:
            points.append((x * width, y * height))

    if len(points) < 8:
        return person, replace_mask, (0, 0, width, height)

    xs = np.asarray([p[0] for p in points])
    ys = np.asarray([p[1] for p in points])
    body_left, body_right = float(xs.min()), float(xs.max())
    body_top, body_bottom = float(ys.min()), float(ys.max())
    body_width = max(1.0, body_right - body_left)
    body_height = max(1.0, body_bottom - body_top)

    # Extra room retains hair, feet, loose sleeves and wide garments. Base the
    # horizontal allowance on body height because wrist-only bounds are often
    # much narrower than the clothing that should be generated.
    left = body_left - max(body_width * 0.20, body_height * 0.10)
    right = body_right + max(body_width * 0.20, body_height * 0.10)
    top = body_top - body_height * 0.10
    bottom = body_bottom + body_height * 0.08

    crop_width = right - left
    crop_height = bottom - top
    if crop_width / crop_height < target_aspect:
        wanted_width = crop_height * target_aspect
        left -= (wanted_width - crop_width) / 2
        right += (wanted_width - crop_width) / 2
    else:
        wanted_height = crop_width / target_aspect
        top -= (wanted_height - crop_height) / 2
        bottom += (wanted_height - crop_height) / 2

    left, right = _fit_interval(left, right, width)
    top, bottom = _fit_interval(top, bottom, height)
    x1, x2 = int(round(left)), int(round(right))
    y1, y2 = int(round(top)), int(round(bottom))

    # Rounding can shift the aspect slightly; it cannot affect inference, but
    # reject pathological crops rather than handing a tiny image to a model.
    if x2 - x1 < 128 or y2 - y1 < 256:
        return person, replace_mask, (0, 0, width, height)

    cropped_person = person[y1:y2, x1:x2]
    cropped_mask = replace_mask[y1:y2, x1:x2]
    return cropped_person, cropped_mask, (x1, y1, x2, y2)


def normalize_tryon_result(
    result: np.ndarray,
    target_width: int,
    target_height: int,
) -> np.ndarray:
    """Return the stable 3:4 output size expected by storage and Flutter."""
    return cv2.resize(
        result,
        (target_width, target_height),
        interpolation=cv2.INTER_LANCZOS4,
    )


def _fit_interval(start: float, end: float, limit: int) -> tuple[float, float]:
    size = min(end - start, float(limit))
    centre = (start + end) / 2
    start = centre - size / 2
    end = centre + size / 2
    if start < 0:
        end -= start
        start = 0.0
    if end > limit:
        start -= end - limit
        end = float(limit)
    return max(0.0, start), min(float(limit), end)
