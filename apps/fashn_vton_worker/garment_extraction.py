"""Select garment pixels from FASHN Human Parser's 18-class label map."""

import cv2
import numpy as np


def garment_mask(labels: np.ndarray, category: str) -> np.ndarray | None:
    # FASHN labels: face, hair, arms, hands, legs, feet, exposed torso.
    # Product-only photos keep the existing background-removal pipeline.
    person = np.isin(labels, [1, 2, 12, 13, 14, 15, 16])
    if np.count_nonzero(person) < max(16, labels.size * 0.001):
        return None
    garment_label = {"Tops": 3, "Pants": 6, "Skirts": 5}[category]
    mask = (labels == garment_label).astype(np.uint8)
    count, components, stats, _ = cv2.connectedComponentsWithStats(mask, connectivity=8)
    if count <= 1:
        return mask
    # Drop isolated label specks while retaining separated sleeves or pant legs.
    areas = stats[1:, cv2.CC_STAT_AREA]
    keep = np.flatnonzero(areas >= max(16, areas.max() * 0.01)) + 1
    return np.isin(components, keep).astype(np.uint8) * 255
