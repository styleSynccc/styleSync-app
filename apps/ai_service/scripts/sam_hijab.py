"""EXPERIMENTAL: hijab mask refinement with SAM (ViT-B, ONNX).

Reuses the ONNX models rembg downloads (`new_session("sam")`, ~375 MB into
~/.u2net) but drives the encoder/decoder directly: rembg's own wrapper
re-encodes the image on every call and merges all candidate masks.

Prompts come from the baseline segmenter: positive points on the cloth beside,
above and below the face, negative points on the face.
"""
import numpy as np
from rembg import new_session
from rembg.sessions.sam import apply_coords, transform_masks, warp_affine

from app.hijab_mediapipe import CLOTHES, FACE_SKIN, OTHERS

INPUT_SIZE = (684, 1024)  # (h, w) the encoder expects


class Sam:
    def __init__(self):
        session = new_session("sam")
        self._enc, self._dec = session.encoder, session.decoder

    def embed(self, rgb: np.ndarray):
        h, w = rgb.shape[:2]
        scale = min(INPUT_SIZE[1] / w, INPUT_SIZE[0] / h)
        matrix = np.array([[scale, 0, 0], [0, scale, 0], [0, 0, 1]])
        image = warp_affine(rgb, matrix[:2], INPUT_SIZE).astype(np.float32)
        embedding = self._enc.run(None, {self._enc.get_inputs()[0].name: image})[0]
        return embedding, (h, w), matrix

    def decode(self, state, points, labels) -> np.ndarray:
        """Boolean mask (h, w) for the prompt. Points are (x, y) in crop pixels."""
        embedding, original, matrix = state
        coords = np.concatenate([np.array(points, float), [[0.0, 0.0]]], axis=0)[None]
        flags = np.concatenate([labels, [-1]])[None].astype(np.float32)
        coords = apply_coords(coords, INPUT_SIZE, 1024).astype(np.float32)
        coords = np.concatenate([coords, np.ones((1, coords.shape[1], 1), np.float32)], axis=2)
        coords = np.matmul(coords, matrix.T)[:, :, :2].astype(np.float32)
        masks, iou, _ = self._dec.run(None, {
            "image_embeddings": embedding,
            "point_coords": coords,
            "point_labels": flags,
            "mask_input": np.zeros((1, 1, 256, 256), np.float32),
            "has_mask_input": np.zeros(1, np.float32),
            "orig_im_size": np.array(INPUT_SIZE, np.float32),
        })
        masks = transform_masks(masks, original, np.linalg.inv(matrix))  # (1, N, h, w)
        return masks[0][int(np.argmax(iou[0]))] > 0


def prompts_from_labels(labels: np.ndarray):
    """(points, point_labels) for SAM from the segmenter's class labels, or None."""
    h, w = labels.shape
    ys, xs = np.nonzero(labels == FACE_SKIN)
    if len(xs) < 30:
        return None
    fx, fy = xs.mean(), ys.mean()
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    fw, fh = x1 - x0, y1 - y0

    positives = [
        (x0 - 0.30 * fw, fy),           # cloth left of the face
        (x1 + 0.30 * fw, fy),           # cloth right of the face
        (fx, y0 - 0.25 * fh),           # cloth above the face
        (fx, y1 + 0.35 * fh),           # cloth under the chin
    ]
    points, flags = [], []
    for x, y in positives:
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < w and 0 <= yi < h and labels[yi, xi] in (CLOTHES, OTHERS):
            points.append((xi, yi))
            flags.append(1)
    if not points:
        return None
    points += [(fx, fy), (fx, y0 + 0.3 * fh)]   # keep the face out
    flags += [0, 0]
    return points, flags
