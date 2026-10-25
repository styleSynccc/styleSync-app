import base64
import json

import cv2
import numpy as np
from fastapi.testclient import TestClient

from app.config import Settings
from app.errors import TryOnUnavailableError
from app.main import create_app
from tests.conftest import FakeEngine
from tests.test_list_endpoints import seed_twin


class InspoEngine:
    name = "fake-inspo"

    def __init__(self):
        self.calls = 0

    def apply_outfit(self, person, reference):
        self.calls += 1
        assert reference.shape == (800, 600, 3)
        return np.full_like(person, 137)


def reference_photo():
    ok, jpg = cv2.imencode(".jpg", np.full((800, 600, 3), 180, np.uint8))
    assert ok
    return jpg.tobytes()


def make_app(tmp_path, engine, auth_disabled=True, **settings):
    return create_app(settings=Settings(data_dir=tmp_path, auth_disabled=auth_disabled, **settings),
                      engine=FakeEngine(), inspo_engine=engine)


def test_inspo_returns_and_persists_result(tmp_path):
    seed_twin(tmp_path, "mine", "2026-01-01")
    engine = InspoEngine()
    with TestClient(make_app(tmp_path, engine)) as client:
        response = client.post("/v1/inspo", data={"twinId": "mine"},
                               files={"file": ("reference.jpg", reference_photo(), "image/jpeg")})
    assert response.status_code == 201, response.text
    body = response.json()
    assert base64.b64decode(body["resultImageB64"]).startswith(b"\xff\xd8")
    assert body["metadata"]["source"] == "inspo"
    assert body["metadata"]["generationMode"] == "quality"
    metadata = tmp_path / "results" / "dev-user" / body["resultId"] / "metadata.json"
    assert json.loads(metadata.read_text())["twinId"] == "mine"
    assert engine.calls == 1


def test_inspo_rejects_other_users_twin_without_calling_provider(tmp_path):
    seed_twin(tmp_path, "theirs", "2026-01-01", uid="someone-else")
    engine = InspoEngine()
    with TestClient(make_app(tmp_path, engine)) as client:
        response = client.post("/v1/inspo", data={"twinId": "theirs"},
                               files={"file": ("ref.jpg", reference_photo())})
    assert response.status_code == 404
    assert engine.calls == 0


def test_inspo_requires_firebase_auth(tmp_path):
    with TestClient(make_app(tmp_path, InspoEngine(), auth_disabled=False)) as client:
        response = client.post("/v1/inspo", data={"twinId": "mine"},
                               files={"file": ("ref.jpg", reference_photo())})
    assert response.status_code == 401


def test_inspo_validates_before_paid_generation(tmp_path):
    seed_twin(tmp_path, "mine", "2026-01-01")
    engine = InspoEngine()
    with TestClient(make_app(tmp_path, engine)) as client:
        for content in (b"not an image", b""):
            response = client.post("/v1/inspo", data={"twinId": "mine"},
                                   files={"file": ("ref.jpg", content)})
            assert response.status_code == 400
        response = client.post("/v1/inspo", data={"twinId": "../other"},
                               files={"file": ("ref.jpg", reference_photo())})
        assert response.status_code == 400
    assert engine.calls == 0


def test_inspo_missing_key_returns_actionable_error(tmp_path):
    seed_twin(tmp_path, "mine", "2026-01-01")
    app = create_app(settings=Settings(data_dir=tmp_path, auth_disabled=True), engine=FakeEngine())
    with TestClient(app) as client:
        response = client.post("/v1/inspo", data={"twinId": "mine"},
                               files={"file": ("ref.jpg", reference_photo())})
    assert response.status_code == 503
    assert "FASHN_API_KEY" in response.json()["message"]
    assert not (tmp_path / "results").exists()


def test_provider_failure_does_not_save_a_result(tmp_path):
    class FailingEngine(InspoEngine):
        def apply_outfit(self, person, reference):
            raise TryOnUnavailableError("Insufficient credits")
    seed_twin(tmp_path, "mine", "2026-01-01")
    with TestClient(make_app(tmp_path, FailingEngine())) as client:
        response = client.post("/v1/inspo", data={"twinId": "mine"},
                               files={"file": ("ref.jpg", reference_photo())})
    assert response.status_code == 503
    assert not (tmp_path / "results").exists()
