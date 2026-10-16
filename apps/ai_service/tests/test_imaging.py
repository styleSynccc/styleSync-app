import io

import numpy as np
from PIL import Image

from app.imaging import load_and_fix_orientation


def test_transparent_product_image_is_flattened_on_white():
    rgba = np.zeros((300, 300, 4), np.uint8)
    rgba[100:200, 100:200] = (255, 0, 0, 255)
    output = io.BytesIO()
    Image.fromarray(rgba, "RGBA").save(output, format="PNG")

    bgr = load_and_fix_orientation(output.getvalue(), 1_000_000)

    assert tuple(bgr[0, 0]) == (255, 255, 255)
    assert tuple(bgr[150, 150]) == (0, 0, 255)
