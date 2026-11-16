"""Exercise mode selection and billing through both API routes, without paid calls."""
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.fashn_api import FashnApiTryOnEngine
from app.main import create_app
from tests.conftest import FakeEngine
from tests.test_fashn_api import FakeResponse, _image_data_uri
from tests.test_inspo_api import reference_photo
from tests.test_tryon_api import seed_item, seed_twin


@pytest.fixture
def mode_api(tmp_path, monkeypatch):
    seed_twin(tmp_path)
    seed_item(tmp_path, item_id="top", category="Tops")
    seed_item(tmp_path, item_id="pants", category="Pants")
    calls = []
    monkeypatch.setattr("app.fashn_api.requests.post", lambda *a, **kw:
                        (calls.append(kw["json"]) or FakeResponse({"id": "mock"})))
    monkeypatch.setattr("app.fashn_api.requests.get", lambda *a, **kw:
                        FakeResponse({"status": "completed", "output": [_image_data_uri()]}))
    engine = FashnApiTryOnEngine("test-secret", poll_interval_seconds=0)
    app = create_app(
        settings=Settings(data_dir=tmp_path, auth_disabled=True), engine=FakeEngine(),
        tryon_engine=engine, inspo_engine=engine,
    )
    with TestClient(app) as client:
        yield client, calls, engine


def generate(client, endpoint, mode, quote):
    if endpoint == "tryon":
        return client.post("/v1/tryon", json={
            "twinId": "twin1", "garmentItemIds": ["top", "pants"],
            "generationMode": mode, "confirmedCredits": quote,
        })
    data = {"twinId": "twin1", "generationMode": mode}
    if quote is not None:
        data["confirmedCredits"] = str(quote)
    return client.post("/v1/inspo", data=data,
                       files={"file": ("reference.jpg", reference_photo())})


@pytest.mark.parametrize("endpoint,passes", [("tryon", 2), ("inspo", 1)])
@pytest.mark.parametrize("mode,credits", [("fast", 1), ("balanced", 2), ("quality", 3)])
def test_mode_controls_provider_payload_credit_total_and_saved_metadata(mode_api, endpoint, passes, mode, credits):
    client, calls, shared_engine = mode_api
    response = generate(client, endpoint, mode, credits * passes)
    assert response.status_code == 201, response.text
    assert len(calls) == passes
    assert all(call["inputs"]["generation_mode"] == mode for call in calls)
    assert all(call["inputs"]["resolution"] == "1k" for call in calls)
    metadata = response.json()["metadata"]
    assert metadata["generationMode"] == mode
    assert metadata["estimatedCredits"] == credits * passes
    assert metadata["generationPasses"] == passes
    assert shared_engine.generation_mode == "quality"
    assert shared_engine.credits_per_image == 3


@pytest.mark.parametrize("endpoint,passes", [("tryon", 2), ("inspo", 1)])
@pytest.mark.parametrize("mode,wrong_credits", [("fast", 3), ("balanced", 1), ("quality", 2)])
def test_wrong_mode_quote_never_submits_a_paid_call(mode_api, endpoint, passes, mode, wrong_credits):
    client, calls, _ = mode_api
    response = generate(client, endpoint, mode, wrong_credits * passes)
    assert response.status_code == 409
    assert response.json()["error_type"] == "CREDIT_CONFIRMATION_REQUIRED"
    assert calls == []


@pytest.mark.parametrize("endpoint", ["tryon", "inspo"])
@pytest.mark.parametrize("mode", ["turbo", "FAST", "fast "])
def test_invalid_modes_never_submit_a_paid_call(mode_api, endpoint, mode):
    client, calls, _ = mode_api
    response = generate(client, endpoint, mode, 3)
    assert response.status_code == 422
    assert calls == []


@pytest.mark.parametrize("endpoint", ["tryon", "inspo"])
def test_missing_fast_quote_never_submits_a_paid_call(mode_api, endpoint):
    client, calls, _ = mode_api
    assert generate(client, endpoint, "fast", None).status_code == 409
    assert calls == []


def test_requests_with_different_modes_do_not_change_each_others_engine():
    original = FashnApiTryOnEngine("test-secret", base_url="http://mock", timeout_seconds=50,
                                 poll_interval_seconds=0)
    fast = original.with_generation_mode("fast")
    balanced = original.with_generation_mode("balanced")
    assert (fast.generation_mode, fast.credits_per_image) == ("fast", 1)
    assert (balanced.generation_mode, balanced.credits_per_image) == ("balanced", 2)
    assert (original.generation_mode, original.credits_per_image) == ("quality", 3)
    assert fast.base_url == original.base_url
    assert fast.timeout_seconds == original.timeout_seconds
    assert fast.poll_interval_seconds == 0
