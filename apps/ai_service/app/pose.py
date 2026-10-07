from dataclasses import dataclass
from typing import Sequence

LEFT_SHOULDER, RIGHT_SHOULDER = 11, 12
LEFT_WRIST, RIGHT_WRIST = 15, 16
LEFT_HIP, RIGHT_HIP = 23, 24
LEFT_KNEE, RIGHT_KNEE = 25, 26


@dataclass(frozen=True)
class Landmark:
    x: float
    y: float
    z: float
    visibility: float


@dataclass(frozen=True)
class PoseThresholds:
    """Tunable with scripts/check_pose.py against real hijab / loose-clothing photos.

    Basis: 21 valid front-facing photos plus 5 negatives (side profile, sitting,
    three-quarter, hands behind back, body turned away).

    Head direction and body cropping are deliberately not checked: the app
    instructs users to face the camera and show their whole body.
    """

    # Shoulder width / shoulder-to-hip length. Scale-invariant, unlike shoulder
    # width as a fraction of the image, which flagged front-facing people who
    # were small in frame. Valid photos: 0.78-0.94; side/three-quarter: 0.11-0.62.
    min_shoulder_torso_ratio: float = 0.70
    min_thigh_to_torso: float = 0.4
    # Valid photos measured 0.59+. Loose or puffy sleeves lower this score, and
    # a hands-behind-back photo measured 0.58, so no threshold separates them;
    # 0.5 favours not rejecting valid users.
    min_wrist_visibility: float = 0.5
    # Long abayas and skirts hide hips and knees; below this we skip the
    # sitting test instead of guessing from extrapolated joints.
    min_lower_body_visibility: float = 0.5


@dataclass(frozen=True)
class PoseCheck:
    ok: bool
    reason: str = "OK"
    message: str = "Pose is valid and ready for processing."
    skipped: tuple[str, ...] = ()


def _fail(reason: str, message: str, skipped: tuple[str, ...] = ()) -> PoseCheck:
    return PoseCheck(False, reason, message, skipped)


def validate_pose_for_tryon(
    lm: Sequence[Landmark], t: PoseThresholds = PoseThresholds()
) -> PoseCheck:
    ls, rs = lm[LEFT_SHOULDER], lm[RIGHT_SHOULDER]
    skipped: list[str] = []

    shoulder_y = (ls.y + rs.y) / 2
    hip_y = (lm[LEFT_HIP].y + lm[RIGHT_HIP].y) / 2
    torso = abs(hip_y - shoulder_y)
    ratio = abs(ls.x - rs.x) / torso if torso > 1e-6 else 0.0
    if ratio < t.min_shoulder_torso_ratio:
        return _fail("SIDE_PROFILE", "Side profile detected. Please stand facing directly towards the camera.")

    lower = (lm[LEFT_HIP], lm[RIGHT_HIP], lm[LEFT_KNEE], lm[RIGHT_KNEE])
    if all(p.visibility >= t.min_lower_body_visibility for p in lower):
        knee_y = (lm[LEFT_KNEE].y + lm[RIGHT_KNEE].y) / 2
        thigh = abs(knee_y - hip_y)
        if thigh < torso * t.min_thigh_to_torso:
            return _fail("SITTING", "Sitting or squatting posture detected. Please upload a full standing photo.")
    else:
        skipped.append("sitting")

    if lm[LEFT_WRIST].visibility < t.min_wrist_visibility or lm[RIGHT_WRIST].visibility < t.min_wrist_visibility:
        return _fail(
            "ARMS_HIDDEN",
            "Hands/arms are hidden or behind your back. Please keep your arms visible at your sides.",
            tuple(skipped),
        )

    return PoseCheck(True, skipped=tuple(skipped))
