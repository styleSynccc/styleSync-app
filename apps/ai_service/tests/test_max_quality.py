import base64

import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from tests.conftest import FakeEngine
from tests.test_tryon_api import seed_item, seed_twin
from tests.test_inspo_api import reference_photo


class PaidEngine:
    name = "fake-paid-no-network"
    resolution = "1k"
    generation_mode = "quality"
    credits_per_image = 3
    preserves_output_resolution = True
    configured = True

    def __init__(self):
        self.calls = []

    def apply_garment(self, person, product, category, mask):
        self.calls.append((category, person.shape))
        return np.full((1152, 864, 3), 137, np.uint8)

    def apply_outfit(self, person, reference):
        self.calls.append(("inspo", person.shape))
        return np.full((1152, 864, 3), 137, np.uint8)


def app_for(tmp_path, engine):
    return create_app(settings=Settings(data_dir=tmp_path, auth_disabled=True),
                      engine=FakeEngine(), tryon_engine=engine, inspo_engine=engine)


@pytest.mark.parametrize("quote", [None, 0, 3, 10, True])
def test_two_item_quote_must_be_six_before_any_paid_call(tmp_path, quote):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top", category="Tops")
    seed_item(tmp_path, item_id="pants", category="Pants")
    engine = PaidEngine()
    with TestClient(app_for(tmp_path, engine)) as client:
        response = client.post("/v1/tryon", json={
            "twinId": "twin1", "garmentItemIds": ["pants", "top"],
            "confirmedCredits": quote,
        })
    assert response.status_code in {409, 422}
    assert engine.calls == []


def test_two_paid_passes_keep_provider_size_between_steps_and_in_saved_result(tmp_path):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top", category="Tops")
    seed_item(tmp_path, item_id="pants", category="Pants")
    engine = PaidEngine()
    with TestClient(app_for(tmp_path, engine)) as client:
        response = client.post("/v1/tryon", json={
            "twinId": "twin1", "garmentItemIds": ["pants", "top"],
            "confirmedCredits": 6,
        })
    assert response.status_code == 201, response.text
    body = response.json()
    assert engine.calls == [("Tops", (1024, 768, 3)), ("Pants", (1152, 864, 3))]
    raw = base64.b64decode(body["resultImageB64"])
    assert cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_COLOR).shape == (1152, 864, 3)
    metadata = body["metadata"]
    assert metadata["estimatedCredits"] == 6
    assert metadata["generationMode"] == "quality"
    assert metadata["resolution"] == "1k"
    assert metadata["imageWidth"] == 864
    stored = cv2.imread(str(tmp_path / "results/dev-user" / body["resultId"] / "result.jpg"))
    assert stored.shape == (1152, 864, 3)


@pytest.mark.parametrize("quote", [None, 2, 5])
def test_inspo_requires_three_credit_quote_without_provider_calls(tmp_path, quote):
    seed_twin(tmp_path)
    engine = PaidEngine()
    data = {"twinId": "twin1"}
    if quote is not None:
        data["confirmedCredits"] = str(quote)
    with TestClient(app_for(tmp_path, engine)) as client:
        response = client.post("/v1/inspo", data=data,
                               files={"file": ("ref.jpg", reference_photo())})
    assert response.status_code == 409
    assert engine.calls == []


def test_inspo_single_three_credit_pass_preserves_provider_size(tmp_path):
    seed_twin(tmp_path)
    engine = PaidEngine()
    with TestClient(app_for(tmp_path, engine)) as client:
        response = client.post("/v1/inspo", data={"twinId": "twin1", "confirmedCredits": "3"},
                               files={"file": ("ref.jpg", reference_photo())})
    assert response.status_code == 201, response.text
    assert len(engine.calls) == 1
    body = response.json()
    assert body["metadata"]["estimatedCredits"] == 3
    assert body["metadata"]["imageHeight"] == 1152
