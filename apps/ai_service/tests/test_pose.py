from app.pose import Landmark, validate_pose_for_tryon
from tests.conftest import standing_landmarks


def test_valid_standing_pose():
    check = validate_pose_for_tryon(standing_landmarks())
    assert check.ok and check.skipped == ()


def test_side_profile():
    lm = standing_landmarks(l11=Landmark(0.48, 0.25, 0, 1), l12=Landmark(0.52, 0.25, 0, 1))
    assert validate_pose_for_tryon(lm).reason == "SIDE_PROFILE"


def test_small_front_facing_person_is_not_a_side_profile():
    # Person fills little of the frame: shoulders only 0.10 apart in image
    # width, but the torso is short too, so the ratio (0.77) is front-facing.
    lm = standing_landmarks(
        l11=Landmark(0.45, 0.25, 0, 1), l12=Landmark(0.55, 0.25, 0, 1),
        l23=Landmark(0.47, 0.38, 0, 1), l24=Landmark(0.53, 0.38, 0, 1),
        l25=Landmark(0.47, 0.52, 0, 1), l26=Landmark(0.53, 0.52, 0, 1),
    )
    assert validate_pose_for_tryon(lm).ok


def test_sitting():
    lm = standing_landmarks(l25=Landmark(0.43, 0.55, 0, 1), l26=Landmark(0.57, 0.55, 0, 1))
    assert validate_pose_for_tryon(lm).reason == "SITTING"


def test_hidden_arms():
    lm = standing_landmarks(l15=Landmark(0.35, 0.5, 0, 0.2))
    assert validate_pose_for_tryon(lm).reason == "ARMS_HIDDEN"


def test_loose_sleeves_with_borderline_wrist_visibility_are_accepted():
    # Real valid photo measured 0.59; the old 0.6 limit rejected it.
    lm = standing_landmarks(l16=Landmark(0.65, 0.5, 0, 0.55))
    assert validate_pose_for_tryon(lm).ok


def test_head_direction_is_not_checked():
    # Instructions to the user cover this; the pipeline does not reject on it.
    assert validate_pose_for_tryon(standing_landmarks(l0=Landmark(0.70, 0.10, 0, 1))).ok


def test_hidden_knees_skip_sitting_test_instead_of_rejecting():
    # Long abaya: MediaPipe extrapolates knees that sit too close to the hips.
    # Without the visibility guard this would be rejected as "sitting".
    lm = standing_landmarks(l25=Landmark(0.43, 0.55, 0, 0.1), l26=Landmark(0.57, 0.55, 0, 0.1))
    check = validate_pose_for_tryon(lm)
    assert check.ok and check.skipped == ("sitting",)
