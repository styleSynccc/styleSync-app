import json

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.hijab import HijabResult
from app.imaging import composite_on_white, resize_and_pad
from app.main import create_app
from app.pose import Landmark
from tests.conftest import FakeEngine, standing_landmarks


def make_client(tmp_path, engine, hijab=None, **settings):
    settings = Settings(data_dir=tmp_path, auth_disabled=True, **settings)
    app = create_app(settings=settings, engine=engine, hijab_analyzer=hijab)
    return TestClient(app)


def post(client, data, name="me.jpg"):
    return client.post("/v1/twins", files={"file": (name, data, "application/octet-stream")})


def test_happy_path_saves_all_artifacts(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine(standing_landmarks())) as client:
        r = post(client, photo_bytes)
    assert r.status_code == 201
    body = r.json()
    meta = body["metadata"]
    assert meta["status"] == "ready" and meta["wearsHijab"] is None
    assert meta["hijabAnalyzer"] == "none" and meta["pipelineVersion"]
    assert len(body["landmarks"]) == 33 and body["personImageB64"]

    folder = tmp_path / "twins" / "dev-user" / body["twinId"]
    names = {p.name for p in folder.iterdir()}
    assert names == {"original.jpg", "processed.jpg", "landmarks.json", "metadata.json"}
    processed = cv2.imread(str(folder / "processed.jpg"))
    assert processed.shape == (1024, 768, 3)
    assert json.loads((folder / "metadata.json").read_text())["twinId"] == body["twinId"]


def test_hijab_mask_is_saved_when_analyzer_provides_one(tmp_path, photo_bytes):
    class Analyzer:
        name = "fake"

        def analyze(self, image_bgr, landmarks):
            mask = np.zeros(image_bgr.shape[:2], np.uint8)
            mask[:100] = 255
            return HijabResult(wears_hijab=True, confidence=0.9, mask=mask)

    with make_client(tmp_path, FakeEngine(standing_landmarks()), Analyzer()) as client:
        body = post(client, photo_bytes).json()
    assert body["metadata"]["wearsHijab"] is True
    mask = cv2.imread(str(tmp_path / "twins" / "dev-user" / body["twinId"] / "hijab_mask.png"), 0)
    assert mask.shape == (1024, 768)


def test_no_body_is_422_and_skips_background_removal(tmp_path, photo_bytes):
    engine = FakeEngine(landmarks=None)
    with make_client(tmp_path, engine) as client:
        r = post(client, photo_bytes)
    assert r.status_code == 422 and r.json()["error_type"] == "NO_BODY_DETECTED"
    assert engine.bg_calls == 0


def test_bad_posture_is_rejected_before_background_removal(tmp_path, photo_bytes):
    engine = FakeEngine(standing_landmarks(l12=Landmark(0.52, 0.25, 0, 1)))
    with make_client(tmp_path, engine) as client:
        r = post(client, photo_bytes)
    assert r.status_code == 422
    assert r.json()["error_type"] == "INVALID_POSTURE" and r.json()["reason"] == "SIDE_PROFILE"
    assert engine.bg_calls == 0
    assert not (tmp_path / "twins").exists()


def test_garbage_bytes_are_400(tmp_path):
    with make_client(tmp_path, FakeEngine(standing_landmarks())) as client:
        r = post(client, b"not an image")
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_IMAGE"


def test_oversized_upload_is_rejected(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine(standing_landmarks()), max_upload_bytes=100) as client:
        r = post(client, photo_bytes)
    assert r.status_code in (400, 413)


def test_pixel_bomb_is_rejected(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine(standing_landmarks()), max_pixels=1000) as client:
        r = post(client, photo_bytes)
    assert r.status_code == 400


def test_50mp_phone_photo_is_accepted(tmp_path):
    # Budget Samsung phones produce ~8160x6120 photos. Must not hit a size limit.
    ok, buf = cv2.imencode(".jpg", np.full((6120, 8160, 3), 120, np.uint8))
    with make_client(tmp_path, FakeEngine(standing_landmarks())) as client:
        r = post(client, buf.tobytes())
    assert r.status_code == 201, r.text
    meta = r.json()["metadata"]
    assert (meta["imageWidth"], meta["imageHeight"]) == (768, 1024)


def test_too_small_photo_is_rejected(tmp_path):
    ok, buf = cv2.imencode(".jpg", np.full((300, 200, 3), 120, np.uint8))
    with make_client(tmp_path, FakeEngine(standing_landmarks())) as client:
        r = post(client, buf.tobytes())
    assert r.status_code == 400 and "too small" in r.json()["message"]


def test_auth_required_when_not_disabled(tmp_path, photo_bytes):
    settings = Settings(data_dir=tmp_path, auth_disabled=False)
    app = create_app(settings=settings, engine=FakeEngine(standing_landmarks()))
    with TestClient(app) as client:
        assert post(client, photo_bytes).status_code == 401


def test_resize_and_pad_keeps_aspect_and_centres():
    out = resize_and_pad(np.zeros((500, 1000, 3), np.uint8), 768, 1024)
    assert out.shape == (1024, 768, 3)
    assert (out[0] == 255).all() and (out[-1] == 255).all()  # white bars top and bottom
    assert (out[512] == 0).all()                              # image centred


def test_composite_on_white():
    rgba = np.zeros((2, 2, 4), np.uint8)
    rgba[0, 0] = (10, 20, 30, 255)  # opaque
    rgba[0, 1] = (10, 20, 30, 0)    # transparent
    out = composite_on_white(rgba)
    assert tuple(out[0, 0]) == (10, 20, 30)
    assert tuple(out[0, 1]) == (255, 255, 255)
