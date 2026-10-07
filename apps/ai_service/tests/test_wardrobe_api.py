import cv2
import numpy as np
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.conftest import FakeEngine


def make_client(tmp_path, engine, **settings):
    settings = Settings(data_dir=tmp_path, auth_disabled=True, **settings)
    app = create_app(settings=settings, engine=engine)
    return TestClient(app)


def post_item(client, data, category, style=None, name="item.jpg"):
    form = {"category": category}
    if style is not None:
        form["style"] = style
    return client.post("/v1/wardrobe", files={"file": (name, data, "application/octet-stream")}, data=form)


class BlankEngine:
    """remove_background that keeps nothing, as if the photo were empty/background-only."""

    def detect_pose(self, image_bgr):
        return None

    def remove_background(self, png_bytes):
        decoded = cv2.imdecode(np.frombuffer(png_bytes, np.uint8), cv2.IMREAD_COLOR)
        rgba = np.dstack([decoded, np.zeros(decoded.shape[:2], np.uint8)])
        ok, buf = cv2.imencode(".png", rgba)
        return buf.tobytes()


def test_garment_item_saved_without_mask(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine()) as client:
        r = post_item(client, photo_bytes, "Tops")
    assert r.status_code == 201, r.text
    body = r.json()
    meta = body["metadata"]
    assert meta["category"] == "Tops" and meta["style"] is None
    assert meta["status"] == "ready" and meta["pipelineVersion"]
    assert body["itemImageB64"]

    folder = tmp_path / "wardrobe" / "dev-user" / body["itemId"]
    assert {p.name for p in folder.iterdir()} == {"original.jpg", "processed.jpg", "metadata.json"}
    assert cv2.imread(str(folder / "processed.jpg")).shape == (1024, 768, 3)


def test_hijab_item_saves_style_and_mask(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine()) as client:
        r = post_item(client, photo_bytes, "Hijab", style="pashmina")
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["metadata"]["category"] == "Hijab" and body["metadata"]["style"] == "pashmina"

    folder = tmp_path / "wardrobe" / "dev-user" / body["itemId"]
    assert "mask.png" in {p.name for p in folder.iterdir()}
    mask = cv2.imread(str(folder / "mask.png"), cv2.IMREAD_GRAYSCALE)
    assert mask.shape == (1024, 768)
    assert (mask == 255).all()  # FakeEngine keeps the whole frame as foreground


def test_unknown_category_is_rejected(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine()) as client:
        r = post_item(client, photo_bytes, "socks")
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_CATEGORY"


def test_hijab_without_style_is_rejected(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine()) as client:
        r = post_item(client, photo_bytes, "Hijab")
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_STYLE"


def test_hijab_with_unknown_style_is_rejected(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine()) as client:
        r = post_item(client, photo_bytes, "Hijab", style="turban")
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_STYLE"


def test_style_is_ignored_for_non_hijab_category(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine()) as client:
        r = post_item(client, photo_bytes, "Tops", style="pashmina")
    assert r.status_code == 201 and r.json()["metadata"]["style"] is None


def test_blank_photo_is_rejected_as_no_garment(tmp_path, photo_bytes):
    with make_client(tmp_path, BlankEngine()) as client:
        r = post_item(client, photo_bytes, "Tops")
    assert r.status_code == 422 and r.json()["error_type"] == "NO_GARMENT_DETECTED"


def test_too_small_photo_is_rejected(tmp_path):
    ok, buf = cv2.imencode(".jpg", np.full((300, 200, 3), 120, np.uint8))
    with make_client(tmp_path, FakeEngine()) as client:
        r = post_item(client, buf.tobytes(), "Tops")
    assert r.status_code == 400 and "too small" in r.json()["message"]


def test_auth_required_when_not_disabled(tmp_path, photo_bytes):
    settings = Settings(data_dir=tmp_path, auth_disabled=False)
    app = create_app(settings=settings, engine=FakeEngine())
    with TestClient(app) as client:
        assert post_item(client, photo_bytes, "Tops").status_code == 401
