"""Build pose-derived clothing masks for engines that require one."""

import cv2
import numpy as np


def clothing_mask(
    shape: tuple[int, int],
    landmarks: list[dict],
    category: str,
    protect_mask: np.ndarray | None = None,
) -> np.ndarray:
    if len(landmarks) < 29:
        raise ValueError("The digital twin does not contain enough pose landmarks.")

    height, width = shape

    def point(index: int) -> tuple[int, int]:
        landmark = landmarks[index]
        x = int(np.clip(float(landmark["x"]), 0.0, 1.0) * (width - 1))
        y = int(np.clip(float(landmark["y"]), 0.0, 1.0) * (height - 1))
        return x, y

    mask = np.zeros((height, width), np.uint8)
    left_shoulder, right_shoulder = point(11), point(12)
    shoulder_width = max(
        24,
        int(np.hypot(
            left_shoulder[0] - right_shoulder[0],
            left_shoulder[1] - right_shoulder[1],
        )),
    )

    if category == "Tops":
        left_elbow, right_elbow = point(13), point(14)
        left_wrist, right_wrist = point(15), point(16)
        left_hip, right_hip = point(23), point(24)
        torso = np.array(
            [left_shoulder, right_shoulder, right_hip, left_hip], np.int32
        )
        cv2.fillConvexPoly(mask, torso, 255)

        arm_width = max(18, int(shoulder_width * 0.30))
        cv2.line(mask, left_shoulder, left_elbow, 255, arm_width)
        cv2.line(mask, left_elbow, left_wrist, 255, arm_width)
        cv2.line(mask, right_shoulder, right_elbow, 255, arm_width)
        cv2.line(mask, right_elbow, right_wrist, 255, arm_width)

        # Preserve the hands at the end of each sleeve.
        hand_radius = max(10, int(shoulder_width * 0.10))
        cv2.circle(mask, left_wrist, hand_radius, 0, -1)
        cv2.circle(mask, right_wrist, hand_radius, 0, -1)
    elif category in {"Pants", "Skirts"}:
        left_hip, right_hip = point(23), point(24)
        left_knee, right_knee = point(25), point(26)
        left_ankle, right_ankle = point(27), point(28)
        hip_width = max(24, abs(left_hip[0] - right_hip[0]))
        leg_width = max(18, int(hip_width * 0.46))
        cv2.line(mask, left_hip, left_knee, 255, leg_width)
        cv2.line(mask, left_knee, left_ankle, 255, leg_width)
        cv2.line(mask, right_hip, right_knee, 255, leg_width)
        cv2.line(mask, right_knee, right_ankle, 255, leg_width)
        cv2.fillConvexPoly(
            mask,
            np.array([left_hip, right_hip, right_knee, left_knee], np.int32),
            255,
        )
    elif category == "Shoes":
        if len(landmarks) < 33:
            raise ValueError("The digital twin does not contain foot landmarks.")
        left_ankle, right_ankle = point(27), point(28)
        left_heel, right_heel = point(29), point(30)
        left_toe, right_toe = point(31), point(32)
        shoe_width = max(22, int(shoulder_width * 0.28))
        for ankle, heel, toe in (
            (left_ankle, left_heel, left_toe),
            (right_ankle, right_heel, right_toe),
        ):
            cv2.line(mask, ankle, heel, 255, shoe_width)
            cv2.line(mask, heel, toe, 255, shoe_width)
            cv2.circle(mask, toe, shoe_width // 2, 255, -1)
    else:
        raise ValueError("Virtual try-on currently supports Tops, Pants, Skirts, and Shoes only.")

    kernel_size = max(5, int(width * 0.018))
    if kernel_size % 2 == 0:
        kernel_size += 1
    mask = cv2.dilate(
        mask,
        np.ones((kernel_size, kernel_size), np.uint8),
        iterations=1,
    )

    if protect_mask is not None:
        if protect_mask.shape != mask.shape:
            protect_mask = cv2.resize(
                protect_mask, (width, height), interpolation=cv2.INTER_NEAREST
            )
        mask[protect_mask > 0] = 0

    return mask
