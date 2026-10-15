import numpy as np

from app.tryon_mask import clothing_mask
from tests.conftest import standing_landmarks


def landmarks_as_dicts():
    return [
        {"x": point.x, "y": point.y, "z": point.z, "visibility": point.visibility}
        for point in standing_landmarks()
    ]


def test_top_mask_covers_torso_but_not_face_or_hands():
    mask = clothing_mask((1024, 768), landmarks_as_dicts(), "Tops")

    assert mask[380, 384] == 255
    assert mask[100, 384] == 0
    assert mask[512, 269] == 0
    assert mask[512, 499] == 0


def test_pants_mask_covers_legs_but_not_torso():
    mask = clothing_mask((1024, 768), landmarks_as_dicts(), "Pants")

    assert mask[700, 330] == 255
    assert mask[300, 384] == 0


def test_protected_pixels_are_removed_from_replacement_mask():
    protect = np.zeros((1024, 768), np.uint8)
    protect[200:400] = 255

    mask = clothing_mask((1024, 768), landmarks_as_dicts(), "Tops", protect)

    assert not mask[200:400].any()
