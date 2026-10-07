"""Test hijab detection and the head-covering mask on any folder of photos.

    python -m scripts.check_hijab samples [out_dir] [--sam]

Prints, per photo: pose verdict, ground truth (if the folder name says so),
the detector's answer, and mask sizes. Saves comparison sheets to out_dir
(default data/hijab_check): head crop | baseline mask (red) | SAM mask (green).

Folder names are used as ground truth: `hijab*` = wears hijab;
`non-hijab*`, `no-hijab*`, `nohijab*` and `men` = does not. Other folders are
reported without a verdict.

--sam also runs the experimental SAM refinement (needs the ~375 MB SAM models,
downloaded on first use; several seconds per photo on CPU).
"""
import sys
import time
from pathlib import Path

import cv2
import numpy as np

from app.config import get_settings
from app.engine import ModelEngine
from app.hijab_mediapipe import FACE_SKIN, MediaPipeHijabAnalyzer, interpret_labels
from app.imaging import load_and_fix_orientation, resize_and_pad
from app.pose import validate_pose_for_tryon

EXTS = {".jpg", ".jpeg", ".png", ".webp"}
PER_SHEET = 8
PANEL = 180


def truth_from_path(path: Path, root: Path) -> bool | None:
    parts = [p.lower() for p in path.relative_to(root).parts[:-1]]
    if any(p.startswith(("non-hijab", "no-hijab", "nohijab")) or p == "men" for p in parts):
        return False
    if any(p.startswith("hijab") for p in parts):
        return True
    return None


def overlay(bgr: np.ndarray, mask: np.ndarray | None, color) -> np.ndarray:
    out = bgr.copy()
    if mask is not None and mask.any():
        m = mask > 0
        out[m] = (0.5 * out[m] + 0.5 * np.array(color)).astype(np.uint8)
    return out


def panel(bgr: np.ndarray) -> np.ndarray:
    return cv2.resize(bgr, (PANEL, int(PANEL * bgr.shape[0] / bgr.shape[1])))


def main(folder: str, out_dir: str = "data/hijab_check", use_sam: bool = False) -> None:
    root = Path(folder)
    settings = get_settings()
    engine = ModelEngine(settings)
    analyzer = MediaPipeHijabAnalyzer(settings.hijab_model_path)
    sam = None
    if use_sam:
        from scripts.sam_hijab import Sam, prompts_from_labels
        sam = Sam()
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    print(f"{'photo':46} {'pose':12} truth  detected  base_px  sam_px  sam_s")
    cells, right, wrong = [], 0, 0
    files = sorted(p for p in root.rglob("*") if p.suffix.lower() in EXTS)
    for path in files:
        name = str(path.relative_to(root))
        label = name if len(name) <= 46 else "..." + name[-43:]
        try:
            raw = load_and_fix_orientation(path.read_bytes(), settings.max_pixels)
        except Exception as e:
            print(f"{label:46} UNREADABLE ({e})")
            continue
        canvas = resize_and_pad(raw, settings.target_width, settings.target_height)
        lm = engine.detect_pose(canvas)
        if lm is None:
            print(f"{label:46} NO_BODY")
            continue

        pose = validate_pose_for_tryon(lm).reason
        seg = analyzer.segment_labels(canvas, lm)
        if seg is None:
            print(f"{label:46} {pose:12} degenerate head crop")
            continue
        labels, box = seg
        result = interpret_labels(labels, box, canvas.shape, lm)
        truth = truth_from_path(path, root)
        mark = ""
        if truth is not None:
            ok = result.wears_hijab == truth
            right += ok
            wrong += not ok
            mark = "" if ok else "  <-- WRONG"

        x0, y0, x1, y1 = box
        crop = canvas[y0:y1, x0:x1]
        base_crop = result.mask[y0:y1, x0:x1] if result.mask is not None else None
        sam_px, sam_s, sam_crop = "-", "-", None
        if sam is not None and result.wears_hijab:
            prompts = prompts_from_labels(labels)
            if prompts is None:
                sam_px = "noprompt"
            else:
                t0 = time.time()
                state = sam.embed(np.ascontiguousarray(cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)))
                m = sam.decode(state, *prompts) & (labels != FACE_SKIN)
                sam_s = f"{time.time() - t0:.1f}"
                sam_crop = m.astype(np.uint8) * 255
                sam_px = str(int(m.sum()))
        base_px = int((result.mask > 0).sum()) if result.mask is not None else 0
        t_txt = "?" if truth is None else str(truth)
        print(f"{label:46} {pose:12} {t_txt:6} {result.wears_hijab!s:9} {base_px:7} {sam_px:>7} {sam_s:>6}{mark}")

        panels = [panel(crop), panel(overlay(crop, base_crop, (0, 0, 255)))]
        if sam is not None:
            panels.append(panel(overlay(crop, sam_crop, (0, 200, 0))))
        cells.append(np.hstack(panels))

    if right + wrong:
        print(f"\ndetection vs folder names: correct={right} wrong={wrong}")

    for k in range(0, len(cells), PER_SHEET):
        chunk = cells[k:k + PER_SHEET]
        height = max(c.shape[0] for c in chunk)
        chunk = [cv2.copyMakeBorder(c, 0, height - c.shape[0], 0, 8, cv2.BORDER_CONSTANT, value=(255, 255, 255))
                 for c in chunk]
        if len(chunk) % 2:
            chunk.append(np.full_like(chunk[0], 255))
        sheet = np.vstack([np.hstack(chunk[j:j + 2]) for j in range(0, len(chunk), 2)])
        cv2.imwrite(str(out / f"hijab_check_{k // PER_SHEET + 1}.jpg"), sheet)
    print(f"sheets written to {out}/  (panels: crop | baseline red"
          + (" | SAM green)" if sam else ")"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args[0], args[1] if len(args) > 1 else "data/hijab_check", "--sam" in sys.argv)
