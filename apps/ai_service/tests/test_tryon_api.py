import cv2
import numpy as np
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.storage import LocalTwinStore, LocalWardrobeStore
from tests.conftest import FakeEngine

CANVAS = (1024, 768, 3)


def seed_twin(tmp_path, uid="dev-user", twin_id="twin1"):
    img = np.full(CANVAS, 200, np.uint8)
    ok, jpg = cv2.imencode(".jpg", img)
    LocalTwinStore(tmp_path).save(
        uid, twin_id, original=jpg.tobytes(), original_ext="jpg",
        processed_jpg=jpg.tobytes(), landmarks=[], hijab_mask_png=None,
        metadata={"twinId": twin_id, "uid": uid},
    )
    return twin_id


def seed_item(tmp_path, uid="dev-user", item_id="item1", category="Tops"):
    img = np.full(CANVAS, 150, np.uint8)
    ok, jpg = cv2.imencode(".jpg", img)
    LocalWardrobeStore(tmp_path).save(
        uid, item_id, original=jpg.tobytes(), original_ext="jpg",
        processed_jpg=jpg.tobytes(), mask_png=None,
        metadata={"itemId": item_id, "uid": uid, "category": category},
    )
    return item_id


class FakeTryOnEngine:
    """Deterministic stand-in: paints the whole image a flat 99."""

    name = "fake"

    def __init__(self):
        self.calls = []  # (category, person pixel at the garment area) per call

    def apply_garment(self, person_bgr, garment_bgr, category):
        self.calls.append((category, int(person_bgr[600, 400, 0])))
        out = person_bgr.copy()
        out[:] = 99  # pretend-garment painted everywhere
        return out


def make_client(tmp_path, tryon_engine=None, **settings):
    settings = Settings(data_dir=tmp_path, auth_disabled=True, **settings)
    app = create_app(settings=settings, engine=FakeEngine(), tryon_engine=tryon_engine)
    return TestClient(app)


def post_tryon(client, twin_id, garment_item_id, start_from=None):
    body = {"twinId": twin_id, "garmentItemId": garment_item_id}
    if start_from is not None:
        body["startFromResultId"] = start_from
    return client.post("/v1/tryon", json=body)


def test_unknown_twin_is_404(tmp_path):
    seed_item(tmp_path)
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_tryon(client, "missing", "item1")
    assert r.status_code == 404 and r.json()["error_type"] == "TWIN_NOT_FOUND"


def test_unknown_garment_is_404(tmp_path):
    seed_twin(tmp_path)
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_tryon(client, "twin1", "missing")
    assert r.status_code == 404 and r.json()["error_type"] == "WARDROBE_ITEM_NOT_FOUND"


def test_result_is_persisted(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        body = post_tryon(client, "twin1", "top1").json()
    folder = tmp_path / "results" / "dev-user" / body["resultId"]
    assert {p.name for p in folder.iterdir()} == {"result.jpg", "metadata.json"}


def test_not_implemented_by_default(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(tmp_path) as client:  # no tryon_engine override
        r = post_tryon(client, "twin1", "top1")
    assert r.status_code == 501 and r.json()["error_type"] == "TRY_ON_NOT_IMPLEMENTED"


def test_auth_required_when_not_disabled(tmp_path):
    seed_twin(tmp_path, uid="dev-user")
    seed_item(tmp_path, uid="dev-user", item_id="top1", category="Tops")
    settings = Settings(data_dir=tmp_path, auth_disabled=False)
    app = create_app(settings=settings, engine=FakeEngine(), tryon_engine=FakeTryOnEngine())
    with TestClient(app) as client:
        assert post_tryon(client, "twin1", "top1").status_code == 401


def test_accessories_cannot_be_tried_on(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="watch1", category="Accessories")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_tryon(client, "twin1", "watch1")
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_WARDROBE_ITEM"
    assert "can't be tried on" in r.json()["message"]


def test_next_item_starts_from_previous_result(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    seed_item(tmp_path, item_id="pants1", category="Pants")
    engine = FakeTryOnEngine()
    with make_client(tmp_path, engine) as client:
        first = post_tryon(client, "twin1", "top1").json()
        r = post_tryon(client, "twin1", "pants1", start_from=first["resultId"])
    assert r.status_code == 201, r.text
    # 1st call saw the bare twin (200), 2nd saw the 1st result (99).
    assert engine.calls == [("Tops", 200), ("Pants", 99)]
    meta = r.json()["metadata"]
    assert meta["startFromResultId"] == first["resultId"]
    assert meta["wearing"] == [
        {"itemId": "top1", "category": "Tops"},
        {"itemId": "pants1", "category": "Pants"},
    ]


def test_same_category_replaces_in_wearing(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    seed_item(tmp_path, item_id="top2", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        first = post_tryon(client, "twin1", "top1").json()
        body = post_tryon(client, "twin1", "top2", start_from=first["resultId"]).json()
    assert body["metadata"]["wearing"] == [{"itemId": "top2", "category": "Tops"}]


def test_unknown_start_result_is_404(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_tryon(client, "twin1", "top1", start_from="missing")
    assert r.status_code == 404 and r.json()["error_type"] == "RESULT_NOT_FOUND"


def test_start_result_from_another_twin_rejected(tmp_path):
    seed_twin(tmp_path, twin_id="twin1")
    seed_twin(tmp_path, twin_id="twin2")
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        first = post_tryon(client, "twin1", "top1").json()
        r = post_tryon(client, "twin2", "top1", start_from=first["resultId"])
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_WARDROBE_ITEM"


def test_fastfit_worker_down_is_503(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    # Nothing listens on port 9: the connection is refused straight away.
    with make_client(tmp_path, fastfit_url="http://127.0.0.1:9") as client:
        r = post_tryon(client, "twin1", "top1")
    assert r.status_code == 503 and r.json()["error_type"] == "TRY_ON_ENGINE_UNAVAILABLE"


def test_fastfit_engine_sends_category(monkeypatch):
    from app import tryon

    sent = {}

    class FakeResponse:
        status_code = 200
        content = cv2.imencode(".jpg", np.full(CANVAS, 99, np.uint8))[1].tobytes()

    def fake_post(url, files, data, timeout):
        sent.update(url=url, data=data)
        return FakeResponse()

    monkeypatch.setattr(tryon.requests, "post", fake_post)
    out = tryon.FastFitTryOnEngine("http://worker/", 5).apply_garment(
        np.full(CANVAS, 200, np.uint8), np.full(CANVAS, 150, np.uint8), "Pants"
    )
    assert sent == {"url": "http://worker/generate", "data": {"category": "lower"}}
    assert abs(int(out[600, 400, 0]) - 99) <= 2  # the image FastFit sent back
