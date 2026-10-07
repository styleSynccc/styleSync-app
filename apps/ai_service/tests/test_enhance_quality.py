import numpy as np

from app.imaging import enhance_quality


def test_denoising_reduces_noise_variance():
    rng = np.random.default_rng(0)
    clean = np.full((200, 200, 3), 128, np.uint8)
    noisy = np.clip(clean.astype(np.int16) + rng.normal(0, 20, clean.shape), 0, 255).astype(np.uint8)
    out = enhance_quality(noisy)
    # Local pixel-to-pixel variance (noise), not overall spread (contrast
    # correction can legitimately widen that) - std of the first difference.
    assert np.std(np.diff(out[..., 0].astype(np.int16), axis=0)) < np.std(np.diff(noisy[..., 0].astype(np.int16), axis=0))


def test_sharpening_increases_edge_contrast():
    import cv2

    img = np.full((200, 200, 3), 50, np.uint8)
    img[:, 100:] = 200  # a hard vertical edge
    blurred = cv2.GaussianBlur(img, (0, 0), 3)  # simulate a slightly soft phone photo
    out = enhance_quality(blurred)

    def edge_strength(image):
        col = image[100, :, 0].astype(np.int16)
        return np.max(np.abs(np.diff(col)))

    assert edge_strength(out) > edge_strength(blurred)


def test_low_contrast_channel_is_stretched():
    # A dim, washed-out photo: all channels crammed into a narrow range.
    img = np.full((100, 100, 3), 120, np.uint8)
    img[:, 50:] = 140
    out = enhance_quality(img)
    assert (out[..., 0].max() - out[..., 0].min()) > (img[..., 0].max() - img[..., 0].min())


def test_does_not_shift_a_dominant_garment_colour():
    # Regression check for the real failure found on real photos: a
    # gray-world white balance (since removed) shifted a navy shirt toward
    # charcoal grey because one strong colour dominated the frame - exactly
    # what a single-garment photo looks like. Hue must survive unchanged;
    # only lightness (contrast) may be touched.
    navy_bgr = (90, 50, 20)  # a dark, fairly saturated blue
    img = np.full((100, 100, 3), navy_bgr, np.uint8)
    img[:, 50:] = (110, 65, 30)  # mild local variation so there's contrast to work with
    out = enhance_quality(img)

    import cv2

    hue_in = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)[..., 0].astype(np.int16)
    hue_out = cv2.cvtColor(out, cv2.COLOR_BGR2HSV)[..., 0].astype(np.int16)
    assert np.abs(int(hue_out.mean()) - int(hue_in.mean())) <= 2


def test_flat_image_is_not_corrupted():
    # FakeEngine's background removal returns a perfectly flat test image.
    # CLAHE on a genuinely flat (zero-variance) region can shift its value
    # arbitrarily (there's nothing to spread across histogram bins) - guarded
    # against explicitly, since this is exactly the shape of our own test
    # fixtures, not just a contrived edge case.
    flat = np.full((50, 50, 3), 100, np.uint8)
    out = enhance_quality(flat)
    assert out.shape == flat.shape and out.dtype == np.uint8
    assert np.array_equal(out, flat)
