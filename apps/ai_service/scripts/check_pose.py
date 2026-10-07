"""Run the real models over a folder of photos (subfolders = groups).

Prints the measurements the checks use, for tuning thresholds. With an output
dir, also saves original | cutout side-by-side images so the background
removal can be inspected by eye (hijab edges, loose clothing).

    python -m scripts.check_pose samples [out_dir]

Columns: sh/torso  shoulder width / shoulder-to-hip length
"""
import sys
from pathlib import Path

import cv2
import numpy as np

from app.config import get_settings
from app.engine import ModelEngine
from app.imaging import (
    composite_on_white,
    encode_png,
    load_and_fix_orientation,
    resize_and_pad,
)
from app.pose import PoseThresholds, validate_pose_for_tryon

EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def main(folder: str, out_dir: str | None = None) -> None:
    root = Path(folder)
    settings = get_settings()
    engine = ModelEngine(settings)
    t = PoseThresholds()
    out = Path(out_dir) if out_dir else None
    if out:
        out.mkdir(parents=True, exist_ok=True)

    print(f"{'photo':50} {'result':13} sh/torso wrists(L/R) lower_vis thigh/torso  size")
    for i, path in enumerate(sorted(p for p in root.rglob("*") if p.suffix.lower() in EXTS)):
        name = str(path.relative_to(root))
        label = name if len(name) <= 50 else "..." + name[-47:]
        try:
            raw = load_and_fix_orientation(path.read_bytes(), settings.max_pixels)
        except Exception as e:
            print(f"{label:50} UNREADABLE ({e})")
            continue
        src_h, src_w = raw.shape[:2]
        img = resize_and_pad(raw, settings.target_width, settings.target_height)

        lm = engine.detect_pose(img)
        if lm is None:
            print(f"{label:50} NO_BODY  {src_w}x{src_h}")
            continue

        check = validate_pose_for_tryon(lm, t)
        sw = abs(lm[11].x - lm[12].x)
        torso = abs((lm[23].y + lm[24].y) / 2 - (lm[11].y + lm[12].y) / 2)
        lower = min(lm[j].visibility for j in (23, 24, 25, 26))
        thigh = abs((lm[25].y + lm[26].y) / 2 - (lm[23].y + lm[24].y) / 2)
        res = check.reason + ("*" if check.skipped else "")
        print(f"{label:50} {res:13} {sw / torso if torso else 0:8.2f} "
              f"{lm[15].visibility:.2f}/{lm[16].visibility:.2f}   {lower:9.2f} "
              f"{thigh / torso if torso else 0:11.2f}  {src_w}x{src_h}")

        if out:
            cut = cv2.imdecode(
                np.frombuffer(engine.remove_background(encode_png(img)), np.uint8),
                cv2.IMREAD_UNCHANGED,
            )
            if cut is not None:
                pair = np.hstack([img, composite_on_white(cut)])
                cv2.imwrite(str(out / f"{i:02d}_{res.strip('*')}_{path.parent.name}.jpg"), pair)

    print("\n* = sitting test skipped (hips/knees not visible)")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
