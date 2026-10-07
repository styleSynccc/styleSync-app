import io

import cv2
import numpy as np
from PIL import Image, ImageOps

from .errors import ImageValidationError


def validate_bytes(data: bytes, max_bytes: int) -> None:
    if len(data) == 0:
        raise ImageValidationError("Uploaded file is empty.")
    if len(data) > max_bytes:
        raise ImageValidationError(
            f"File too large ({len(data) / 1_000_000:.1f}MB). Max is {max_bytes / 1_000_000:.0f}MB."
        )


def sniff_extension(data: bytes) -> str:
    """File extension from the real image format (never from client headers)."""
    try:
        fmt = (Image.open(io.BytesIO(data)).format or "").lower()
    except Exception:
        return "bin"
    return {"jpeg": "jpg"}.get(fmt, fmt or "bin")


def load_and_fix_orientation(data: bytes, max_pixels: int, max_side: int = 3072) -> np.ndarray:
    """Decode, apply EXIF rotation, and return a BGR array no larger than max_side."""
    try:
        pil = Image.open(io.BytesIO(data))
        w, h = pil.size  # header only, nothing decoded yet
        if w * h > max_pixels:
            raise ImageValidationError(f"Image is too large ({w}x{h} pixels).")
        if max(w, h) > max_side:
            # JPEG decodes directly at a reduced size; no-op for other formats.
            pil.draft("RGB", (max(1, w * max_side // max(w, h)), max(1, h * max_side // max(w, h))))
        pil = ImageOps.exif_transpose(pil).convert("RGB")
        if max(pil.size) > max_side:
            pil.thumbnail((max_side, max_side), Image.LANCZOS)
    except ImageValidationError:
        raise
    except Exception as e:
        raise ImageValidationError(f"Could not read image: {e}")
    return cv2.cvtColor(np.array(pil), cv2.COLOR_RGB2BGR)


def validate_resolution(image: np.ndarray, min_short: int, min_long: int) -> None:
    h, w = image.shape[:2]
    if min(w, h) < min_short or max(w, h) < min_long:
        raise ImageValidationError(
            f"Photo is too small ({w}x{h}). Please upload one at least {min_short}x{min_long} pixels."
        )


def fit_box(src_w: int, src_h: int, target_w: int, target_h: int) -> tuple[int, int, int, int]:
    """(x, y, w, h) of the source image inside the padded canvas."""
    scale = min(target_w / src_w, target_h / src_h)
    w = max(1, int(src_w * scale))
    h = max(1, int(src_h * scale))
    return (target_w - w) // 2, (target_h - h) // 2, w, h


def resize_and_pad(image: np.ndarray, target_w: int, target_h: int) -> np.ndarray:
    """Fit inside target_w x target_h without stretching, centred on white."""
    src_h, src_w = image.shape[:2]
    x, y, w, h = fit_box(src_w, src_h, target_w, target_h)

    interp = cv2.INTER_AREA if (w < src_w or h < src_h) else cv2.INTER_CUBIC
    resized = cv2.resize(image, (w, h), interpolation=interp)

    canvas = np.full((target_h, target_w, 3), 255, dtype=np.uint8)
    canvas[y:y + h, x:x + w] = resized
    return canvas


def composite_on_white(image: np.ndarray) -> np.ndarray:
    """Flatten a BGRA image onto white. BGR input is returned unchanged."""
    if image.ndim < 3 or image.shape[2] != 4:
        return image
    alpha = image[:, :, 3:4].astype(np.float32) / 255.0
    bgr = image[:, :, :3].astype(np.float32)
    out = alpha * bgr + (1.0 - alpha) * 255.0
    return np.clip(out + 0.5, 0, 255).astype(np.uint8)


def _local_contrast(image_bgr: np.ndarray) -> np.ndarray:
    """CLAHE on lightness only (LAB's L channel) - boosts local contrast
    without touching hue/saturation, and clips how much any region can be
    boosted, so (unlike a global stretch) it can't blow up noise.

    No white balance here. A gray-world correction (assume the frame should
    average to neutral, scale channels to match) was tried and measurably
    shifted true garment colour on real photos - e.g. a navy shirt read as
    charcoal grey - because gray-world's assumption breaks when one strong
    colour dominates the frame, which is routine for a photo of a single
    garment. For a fashion app, keeping the garment's real colour matters
    more than auto-correcting a colour cast that may not even be wrong. See
    PRD section on quality enhancement for the before/after that showed this.
    """
    if int(image_bgr.max()) - int(image_bgr.min()) < 2:
        return image_bgr  # nothing to correct; CLAHE on a flat input can shift it arbitrarily
    l, a, b = cv2.split(cv2.cvtColor(image_bgr, cv2.COLOR_BGR2LAB))
    l = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(l)
    return cv2.cvtColor(cv2.merge([l, a, b]), cv2.COLOR_LAB2BGR)


def _unsharp_mask(image_bgr: np.ndarray, amount: float = 0.3, sigma: float = 1.5) -> np.ndarray:
    blurred = cv2.GaussianBlur(image_bgr, (0, 0), sigma)
    return cv2.addWeighted(image_bgr, 1 + amount, blurred, -amount, 0)


def enhance_quality(image_bgr: np.ndarray) -> np.ndarray:
    """Light, classic cleanup for phone photos before VTON: reduce sensor
    noise, boost local contrast, restore edge sharpness. No ML model - our
    photos are always downscaled to the 768x1024 target (phones already
    shoot well above that), so there's no low-resolution source to upscale;
    these are classic filters, no new GPU/model dependency.

    Deliberately does NOT correct white balance/colour cast - see
    _local_contrast's docstring for why (it measurably shifted true garment
    colour on real photos).
    """
    # Denoise FIRST: contrast correction before denoising amplifies sensor
    # noise along with everything else. Sharpen LAST, after contrast is
    # corrected - and only lightly: sharpening amplifies noise too (it has
    # no way to tell fine noise texture from fine real detail), so a strong
    # amount here would undo some of what the denoiser just fixed. h=8 was
    # picked empirically: h=4 barely denoised synthetic sensor noise at all,
    # h=8 cut it ~9x with still-mild sharpening (amount=0.3); see
    # tests/test_enhance_quality.py.
    denoised = cv2.fastNlMeansDenoisingColored(
        image_bgr, None, h=8, hColor=8, templateWindowSize=7, searchWindowSize=21
    )
    corrected = _local_contrast(denoised)
    return _unsharp_mask(corrected)


def encode_jpeg(image: np.ndarray, quality: int = 95) -> bytes:
    ok, buf = cv2.imencode(".jpg", image, [int(cv2.IMWRITE_JPEG_QUALITY), quality])
    if not ok:
        raise RuntimeError("JPEG encoding failed")
    return buf.tobytes()


def encode_png(image: np.ndarray) -> bytes:
    ok, buf = cv2.imencode(".png", image)
    if not ok:
        raise RuntimeError("PNG encoding failed")
    return buf.tobytes()
