import numpy as np

from app.hijab_mediapipe import (
    BACKGROUND, BODY_SKIN, CLOTHES, FACE_SKIN, HAIR,
    head_crop_box, interpret_labels,
)
from app.pose import Landmark
from tests.conftest import standing_landmarks

# Canvas 200 tall x 100 wide; the 100x100 crop is its top half.
CANVAS = (200, 100, 3)
BOX = (0, 0, 100, 100)
# Shoulders 40 px apart at y=60, so the mask is cut at row 60 + 0.35*40 = 74.
LM = standing_landmarks(l11=Landmark(0.3, 0.3, 0, 1), l12=Landmark(0.7, 0.3, 0, 1))


def hijab_labels() -> np.ndarray:
    labels = np.full((100, 100), BACKGROUND, np.uint8)
    labels[20:95, 25:75] = CLOTHES      # hijab + shirt: same class
    labels[40:60, 40:60] = FACE_SKIN
    labels[0:10, 0:10] = CLOTHES        # unrelated clothes far from the face
    return labels


def test_head_covered_by_clothing_is_hijab_with_mask():
    r = interpret_labels(hijab_labels(), BOX, CANVAS, LM)
    assert r.wears_hijab is True
    m = r.mask
    assert m.shape == (200, 100)
    assert m[25, 50] == 255           # cloth above the face
    assert m[50, 30] == 255           # cloth beside the face
    assert m[50, 50] == 0             # the face itself is not masked
    assert m[80:].sum() == 0          # nothing below the shoulder cut
    assert m[0:10, 0:10].sum() == 0   # clothing not connected to the face is ignored


def test_visible_hair_is_not_hijab():
    labels = hijab_labels()
    labels[0:20, 50:100] = HAIR       # 10% of the crop
    r = interpret_labels(labels, BOX, CANVAS, LM)
    assert r.wears_hijab is False and r.mask is None


def test_visible_neck_skin_is_not_hijab():
    labels = hijab_labels()
    labels[60:70, 40:60] = BODY_SKIN  # 2% of the crop
    assert interpret_labels(labels, BOX, CANVAS, LM).wears_hijab is False


def test_no_face_means_no_decision():
    labels = hijab_labels()
    labels[labels == FACE_SKIN] = CLOTHES
    r = interpret_labels(labels, BOX, CANVAS, LM)
    assert r.wears_hijab is None and r.mask is None


def test_head_crop_box_is_centred_on_nose_and_clipped_to_canvas():
    lm = standing_landmarks(l0=Landmark(0.5, 0.2, 0, 1),
                            l11=Landmark(0.4, 0.3, 0, 1), l12=Landmark(0.6, 0.3, 0, 1))
    x0, y0, x1, y1 = head_crop_box(lm, 1000, 1000)   # shoulder width 200 px
    # int() truncation of float widths can shift a bound by 1 px
    assert abs(x0 - 220) <= 1 and abs(x1 - 780) <= 1
    assert y0 == 0 and abs(y1 - 500) <= 1  # top clipped at 0
