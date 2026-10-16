import cv2
import numpy as np
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.storage import LocalTwinStore, LocalWardrobeStore
from tests.conftest import FakeEngine

CANVAS = (1024, 768, 3)


def make_client(tmp_path, **settings):
    settings = Settings(data_dir=tmp_path, auth_disabled=True, **settings)
    app = create_app(settings=settings, engine=FakeEngine())
    return TestClient(app)


def seed_twin(tmp_path, twin_id, created_at, uid="dev-user"):
    ok, jpg = cv2.imencode(".jpg", np.full(CANVAS, 200, np.uint8))
    LocalTwinStore(tmp_path).save(
        uid, twin_id, original=jpg.tobytes(), original_ext="jpg",
        processed_jpg=jpg.tobytes(), landmarks=[], hijab_mask_png=None,
        metadata={"twinId": twin_id, "uid": uid, "createdAt": created_at},
    )


def seed_item(tmp_path, item_id, created_at, category="Tops", uid="dev-user"):
    ok, jpg = cv2.imencode(".jpg", np.full(CANVAS, 150, np.uint8))
    LocalWardrobeStore(tmp_path).save(
        uid, item_id, original=jpg.tobytes(), original_ext="jpg",
        processed_jpg=jpg.tobytes(), mask_png=None,
        metadata={"itemId": item_id, "uid": uid, "category": category, "createdAt": created_at},
    )


def test_list_twins_empty(tmp_path):
    with make_client(tmp_path) as client:
        r = client.get("/v1/twins")
    assert r.status_code == 200 and r.json() == {"success": True, "twins": []}


def test_list_twins_newest_first(tmp_path):
    seed_twin(tmp_path, "older", "2026-01-01T00:00:00+00:00")
    seed_twin(tmp_path, "newer", "2026-06-01T00:00:00+00:00")
    with make_client(tmp_path) as client:
        body = client.get("/v1/twins").json()
    assert [t["twinId"] for t in body["twins"]] == ["newer", "older"]
    assert body["twins"][0]["personImageB64"]


def test_list_twins_only_returns_this_users_twins(tmp_path):
    seed_twin(tmp_path, "mine", "2026-01-01T00:00:00+00:00", uid="dev-user")
    seed_twin(tmp_path, "theirs", "2026-01-01T00:00:00+00:00", uid="someone-else")
    with make_client(tmp_path) as client:
        body = client.get("/v1/twins").json()
    assert [t["twinId"] for t in body["twins"]] == ["mine"]


def test_list_wardrobe_newest_first(tmp_path):
    seed_item(tmp_path, "older", "2026-01-01T00:00:00+00:00", category="Tops")
    seed_item(tmp_path, "newer", "2026-06-01T00:00:00+00:00", category="Shoes")
    with make_client(tmp_path) as client:
        body = client.get("/v1/wardrobe").json()
    assert [i["itemId"] for i in body["items"]] == ["newer", "older"]
    assert body["items"][0]["metadata"]["category"] == "Shoes"


def test_list_wardrobe_empty(tmp_path):
    with make_client(tmp_path) as client:
        r = client.get("/v1/wardrobe")
    assert r.status_code == 200 and r.json() == {"success": True, "items": []}


def test_twins_list_requires_auth(tmp_path):
    settings = Settings(data_dir=tmp_path, auth_disabled=False)
    app = create_app(settings=settings, engine=FakeEngine())
    with TestClient(app) as client:
        assert client.get("/v1/twins").status_code == 401


def test_wardrobe_list_requires_auth(tmp_path):
    settings = Settings(data_dir=tmp_path, auth_disabled=False)
    app = create_app(settings=settings, engine=FakeEngine())
    with TestClient(app) as client:
        assert client.get("/v1/wardrobe").status_code == 401
