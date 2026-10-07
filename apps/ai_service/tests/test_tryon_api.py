import cv2
import numpy as np
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.storage import LocalTwinStore, LocalWardrobeStore
from tests.conftest import FakeEngine

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
    LocalTwinStore(tmp_path).save(
        uid, twin_id, original=jpg.tobytes(), original_ext="jpg",
        processed_jpg=jpg.tobytes(), landmarks=[], hijab_mask_png=mask_png,
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

    def apply_hijab(self, person_bgr, hijab_bgr, hijab_mask):
        out = person_bgr.copy()
        out[:300] = 50  # pretend-hijab painted over the top third
        mask = np.zeros(person_bgr.shape[:2], np.uint8)
        mask[:300] = 255
        return out, mask

    def apply_garment(self, person_bgr, garment_bgr, protect_mask):
        out = person_bgr.copy()
        out[:] = 99  # pretend-garment painted everywhere
        if protect_mask is not None:
            out[protect_mask > 0] = person_bgr[protect_mask > 0]  # except protected pixels
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


def test_garment_only_protects_twins_own_hijab(tmp_path):
    seed_twin(tmp_path, own_hijab_mask=True)
    seed_item(tmp_path, item_id="top1", category="Tops")
    with make_client(tmp_path, FakeTryOnEngine()) as client:
        body = post_tryon(client, "twin1", "top1").json()
    assert body["metadata"]["hijabItemId"] is None
    import base64
    result = cv2.imdecode(np.frombuffer(base64.b64decode(body["resultImageB64"]), np.uint8), cv2.IMREAD_COLOR)
    assert (result[:200] == 200).all()   # twin's own hijab area: untouched
    assert (result[300:] == 99).all()    # elsewhere: garment applied


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
    assert (result[:300] == 50).all()    # chosen hijab's own placement: protected from stage 2
    assert (result[300:] == 99).all()    # elsewhere: garment applied


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
