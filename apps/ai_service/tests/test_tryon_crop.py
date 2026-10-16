import numpy as np

from app.tryon_crop import crop_for_tryon, normalize_tryon_result
from tests.conftest import standing_landmarks


def landmark_dicts():
    return [
        {"x": p.x, "y": p.y, "z": p.z, "visibility": p.visibility}
        for p in standing_landmarks()
    ]


def test_crop_removes_empty_side_margins_and_keeps_portrait_aspect():
    person = np.full((1024, 768, 3), 255, np.uint8)
    mask = np.zeros((1024, 768), np.uint8)

    cropped_person, cropped_mask, box = crop_for_tryon(
        person, mask, landmark_dicts()
    )

    assert cropped_person.shape[:2] == cropped_mask.shape
    assert cropped_person.shape[1] < person.shape[1]
    assert abs(cropped_person.shape[1] / cropped_person.shape[0] - 0.75) < 0.01
    assert box != (0, 0, 768, 1024)


def test_invalid_landmarks_leave_the_image_unchanged():
    person = np.zeros((1024, 768, 3), np.uint8)
    mask = np.zeros((1024, 768), np.uint8)

    cropped_person, cropped_mask, box = crop_for_tryon(person, mask, [])

    assert cropped_person is person
    assert cropped_mask is mask
    assert box == (0, 0, 768, 1024)


def test_result_is_normalized_to_storage_size():
    result = np.zeros((700, 525, 3), np.uint8)
    normalized = normalize_tryon_result(result, 768, 1024)
    assert normalized.shape == (1024, 768, 3)
