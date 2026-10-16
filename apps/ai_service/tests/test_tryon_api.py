import cv2
import numpy as np
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.storage import LocalTwinStore, LocalWardrobeStore
from tests.conftest import FakeEngine, standing_landmarks

CANVAS = (1024, 768, 3)


def seed_twin(tmp_path, uid="dev-user", twin_id="twin1", own_hijab_mask=False):
    img = np.full(CANVAS, 200, np.uint8)
    ok, jpg = cv2.imencode(".jpg", img)
    mask_png = None
    if own_hijab_mask:
        m = np.zeros(CANVAS[:2], np.uint8)
        m[:200] = 255  # top strip: "wearing their own hijab" in this photo
        ok2, buf = cv2.imencode(".png", m)
        mask_png = buf.tobytes()
    landmarks = [
        {"x": p.x, "y": p.y, "z": p.z, "visibility": p.visibility}
        for p in standing_landmarks()
    ]
    LocalTwinStore(tmp_path).save(
        uid, twin_id, original=jpg.tobytes(), original_ext="jpg",
        processed_jpg=jpg.tobytes(), landmarks=landmarks, hijab_mask_png=mask_png,
        metadata={"twinId": twin_id, "uid": uid},
    )
    return twin_id


def seed_item(tmp_path, uid="dev-user", item_id="item1", category="Tops", with_mask=False):
    img = np.full(CANVAS, 150, np.uint8)
    ok, jpg = cv2.imencode(".jpg", img)
    mask_png = None
    if with_mask:
        ok2, buf = cv2.imencode(".png", np.full(CANVAS[:2], 255, np.uint8))
        mask_png = buf.tobytes()
    LocalWardrobeStore(tmp_path).save(
        uid, item_id, original=jpg.tobytes(), original_ext="jpg",
        processed_jpg=jpg.tobytes(), mask_png=mask_png,
        metadata={"itemId": item_id, "uid": uid, "category": category,
                  "style": "pashmina" if category == "Hijab" else None},
    )
    return item_id


class FakeTryOnEngine:
    """Deterministic stand-in: fills with a flat value so protection is checkable by eye."""

    name = "fake"

    def __init__(self):
        self.garment_categories = []

    def apply_hijab(self, person_bgr, hijab_bgr, hijab_mask):
        out = person_bgr.copy()
        out[:300] = 50  # pretend-hijab painted over the top third
        mask = np.zeros(person_bgr.shape[:2], np.uint8)
        mask[:300] = 255
        return out, mask

    def apply_garment(self, person_bgr, garment_bgr, category, replace_mask):
        self.garment_categories.append(category)
        out = person_bgr.copy()
        out[replace_mask > 0] = 99
        return out


def make_client(tmp_path, tryon_engine=None, **settings):
    settings = Settings(data_dir=tmp_path, auth_disabled=True, **settings)
    app = create_app(settings=settings, engine=FakeEngine(), tryon_engine=tryon_engine)
    return TestClient(app)


def post_tryon(client, twin_id, garment_item_id, hijab_item_id=None):
    body = {"twinId": twin_id, "garmentItemId": garment_item_id}
    if hijab_item_id is not None:
        body["hijabItemId"] = hijab_item_id
    return client.post("/v1/tryon", json=body)


def post_outfit(client, twin_id, garment_item_ids):
    return client.post(
        "/v1/tryon",
        json={"twinId": twin_id, "garmentItemIds": garment_item_ids},
    )


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


def test_hijab_item_rejected_as_garment(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="hijab1", category="Hijab")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_tryon(client, "twin1", "hijab1")
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_WARDROBE_ITEM"


def test_non_hijab_item_rejected_as_hijab_choice(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    seed_item(tmp_path, item_id="top2", category="Pants")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_tryon(client, "twin1", "top1", hijab_item_id="top2")
    assert r.status_code == 400 and r.json()["error_type"] == "INVALID_WARDROBE_ITEM"


def test_top_and_pants_are_applied_in_stable_order(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="pants1", category="Pants")
    seed_item(tmp_path, item_id="top1", category="Tops")
    engine = FakeTryOnEngine()
    with make_client(tmp_path, engine) as client:
        r = post_outfit(client, "twin1", ["pants1", "top1"])

    assert r.status_code == 201, r.text
    body = r.json()
    assert engine.garment_categories == ["Tops", "Pants"]
    assert body["metadata"]["garmentItemIds"] == ["top1", "pants1"]
    assert body["metadata"]["topItemId"] == "top1"
    assert body["metadata"]["pantsItemId"] == "pants1"


def test_top_pants_and_shoes_are_applied_in_stable_order(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="shoes1", category="Shoes")
    seed_item(tmp_path, item_id="pants1", category="Pants")
    seed_item(tmp_path, item_id="top1", category="Tops")
    engine = FakeTryOnEngine()
    with make_client(tmp_path, engine) as client:
        r = post_outfit(client, "twin1", ["shoes1", "pants1", "top1"])

    assert r.status_code == 201, r.text
    body = r.json()
    assert engine.garment_categories == ["Tops", "Pants", "Shoes"]
    assert body["metadata"]["garmentItemIds"] == ["top1", "pants1", "shoes1"]
    assert body["metadata"]["shoesItemId"] == "shoes1"


def test_two_items_from_the_same_category_are_rejected(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    seed_item(tmp_path, item_id="top2", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_outfit(client, "twin1", ["top1", "top2"])

    assert r.status_code == 400
    assert r.json()["error_type"] == "INVALID_WARDROBE_ITEM"


def test_at_least_one_garment_is_required(tmp_path):
    seed_twin(tmp_path)
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_outfit(client, "twin1", [])

    assert r.status_code == 400
    assert r.json()["error_type"] == "INVALID_WARDROBE_ITEM"


def test_garment_only_protects_twins_own_hijab(tmp_path):
    seed_twin(tmp_path, own_hijab_mask=True)
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        body = post_tryon(client, "twin1", "top1").json()
    assert body["metadata"]["hijabItemId"] is None
    import base64
    result = cv2.imdecode(np.frombuffer(base64.b64decode(body["resultImageB64"]), np.uint8), cv2.IMREAD_COLOR)
    assert (result[:200] == 200).all()   # twin's own hijab area: untouched
    assert (result[350:500, 330:438] == 99).all()  # torso: garment applied


def test_chosen_hijab_runs_both_stages_and_protects_its_own_placement(tmp_path):
    seed_twin(tmp_path)  # no own hijab
    seed_item(tmp_path, item_id="top1", category="Tops")
    seed_item(tmp_path, item_id="hijab1", category="Hijab", with_mask=True)
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        r = post_tryon(client, "twin1", "top1", hijab_item_id="hijab1")
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["metadata"]["hijabItemId"] == "hijab1"
    import base64
    result = cv2.imdecode(np.frombuffer(base64.b64decode(body["resultImageB64"]), np.uint8), cv2.IMREAD_COLOR)
    assert np.allclose(result[20:260, 20:-20], 50, atol=3)  # chosen hijab stays protected
    assert np.allclose(result[350:500, 330:438], 99, atol=2)  # garment applied


def test_result_is_persisted(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        body = post_tryon(client, "twin1", "top1").json()
    folder = tmp_path / "results" / "dev-user" / body["resultId"]
    assert {p.name for p in folder.iterdir()} == {"result.jpg", "metadata.json"}


def test_worker_unavailable_by_default(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(
        tmp_path,
        tryon_worker_url="http://127.0.0.1:1",
        fashn_worker_url="http://127.0.0.1:1",
    ) as client:  # no tryon_engine override
        r = post_tryon(client, "twin1", "top1")
    assert r.status_code == 503 and r.json()["error_type"] == "TRY_ON_UNAVAILABLE"


def test_shoes_explain_missing_hosted_api_key(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="shoes1", category="Shoes")
    with make_client(tmp_path) as client:
        r = post_tryon(client, "twin1", "shoes1")

    assert r.status_code == 503
    assert r.json()["error_type"] == "TRY_ON_UNAVAILABLE"
    assert "FASHN_API_KEY" in r.json()["message"]


def test_auth_required_when_not_disabled(tmp_path):
    seed_twin(tmp_path, uid="dev-user")
    seed_item(tmp_path, uid="dev-user", item_id="top1", category="Tops")
    settings = Settings(data_dir=tmp_path, auth_disabled=False)
    app = create_app(settings=settings, engine=FakeEngine(), tryon_engine=FakeTryOnEngine())
    with TestClient(app) as client:
        assert post_tryon(client, "twin1", "top1").status_code == 401
