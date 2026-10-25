import base64

import cv2
import numpy as np
import pytest

from app.errors import TryOnUnavailableError
from app.fashn_api import FashnApiTryOnEngine


class FakeResponse:
    def __init__(self, body, status_code=200):
        self._body = body
        self.status_code = status_code
        self.ok = 200 <= status_code < 300

    def json(self):
        return self._body


def _image_data_uri(value=123):
    image = np.full((12, 8, 3), value, np.uint8)
    ok, encoded = cv2.imencode(".jpg", image)
    assert ok
    return "data:image/jpeg;base64," + base64.b64encode(encoded).decode("ascii")


def test_shoes_require_server_side_api_key():
    engine = FashnApiTryOnEngine("")
    image = np.zeros((16, 12, 3), np.uint8)
    with pytest.raises(TryOnUnavailableError, match="FASHN_API_KEY"):
        engine.apply_garment(image, image, "Shoes", np.zeros((16, 12), np.uint8))


def test_shoe_generation_submits_polls_and_decodes(monkeypatch):
    submitted = {}

    def fake_post(url, *, headers, json, timeout):
        submitted.update(url=url, headers=headers, json=json, timeout=timeout)
        return FakeResponse({"id": "prediction-1", "error": None})

    def fake_get(url, *, headers, timeout):
        assert url.endswith("/status/prediction-1")
        return FakeResponse(
            {"status": "completed", "output": [_image_data_uri()], "error": None}
        )

    monkeypatch.setattr("app.fashn_api.requests.post", fake_post)
    monkeypatch.setattr("app.fashn_api.requests.get", fake_get)
    engine = FashnApiTryOnEngine("secret", poll_interval_seconds=0)
    person = np.zeros((24, 18, 3), np.uint8)
    result = engine.apply_garment(
        person,
        np.full_like(person, 255),
        "Shoes",
        np.zeros((24, 18), np.uint8),
    )

    assert result.shape == (12, 8, 3)  # Preserve the provider's actual output size.
    assert submitted["json"]["model_name"] == "tryon-max"
    inputs = submitted["json"]["inputs"]
    assert inputs["return_base64"] is True
    assert inputs["generation_mode"] == "quality"
    assert inputs["resolution"] == "1k"
    assert inputs["output_format"] == "png"
    assert submitted["headers"]["Authorization"] == "Bearer secret"


def test_inspo_uses_one_quality_1k_call_and_identity_prompt(monkeypatch):
    submitted = []
    def fake_post(url, **kwargs):
        submitted.append(kwargs["json"])
        return FakeResponse({"id": "inspo-1"})
    monkeypatch.setattr("app.fashn_api.requests.post", fake_post)
    monkeypatch.setattr("app.fashn_api.requests.get", lambda *a, **kw:
                        FakeResponse({"status": "completed", "output": [_image_data_uri()]}))
    engine = FashnApiTryOnEngine("secret", poll_interval_seconds=0)
    person = np.zeros((24, 18, 3), np.uint8)
    assert engine.apply_outfit(person, person).shape == (12, 8, 3)
    assert len(submitted) == 1
    inputs = submitted[0]["inputs"]
    assert inputs["generation_mode"] == "quality"
    assert inputs["resolution"] == "1k"
    assert inputs["num_images"] == 1
    assert inputs["return_base64"] is True
    assert "complete visible outfit" in inputs["prompt"]
    assert "not the reference person's face" in inputs["prompt"]


def test_inspo_invalid_provider_response_is_handled(monkeypatch):
    monkeypatch.setattr("app.fashn_api.requests.post", lambda *a, **kw: FakeResponse([], 500))
    with pytest.raises(TryOnUnavailableError, match="invalid response"):
        FashnApiTryOnEngine("secret").apply_outfit(
            np.zeros((24, 18, 3), np.uint8), np.zeros((24, 18, 3), np.uint8))


def test_accessories_request_quality_1k_and_preserve_clothing(monkeypatch):
    submitted = []
    monkeypatch.setattr("app.fashn_api.requests.post", lambda *a, **kw:
                        (submitted.append(kw["json"]) or FakeResponse({"id": "accessory-1"})))
    monkeypatch.setattr("app.fashn_api.requests.get", lambda *a, **kw:
                        FakeResponse({"status": "completed", "output": [_image_data_uri()]}))
    person = np.zeros((24, 18, 3), np.uint8)
    result = FashnApiTryOnEngine("secret", poll_interval_seconds=0).apply_garment(
        person, person, "Accessories", np.zeros((24, 18), np.uint8))
    assert result.shape == (12, 8, 3)
    assert len(submitted) == 1
    inputs = submitted[0]["inputs"]
    assert inputs["generation_mode"] == "quality"
    assert inputs["resolution"] == "1k"
    assert inputs["num_images"] == 1
    assert "existing clothes" in inputs["prompt"]
    assert "only the accessory" in inputs["prompt"]


@pytest.mark.parametrize("category", ["Tops", "Pants", "Skirts"])
def test_all_clothing_uses_quality_1k_once_with_hijab_preservation(monkeypatch, category):
    calls = []
    monkeypatch.setattr("app.fashn_api.requests.post", lambda *a, **kw:
                        (calls.append(kw["json"]) or FakeResponse({"id": "clothes"})))
    monkeypatch.setattr("app.fashn_api.requests.get", lambda *a, **kw:
                        FakeResponse({"status": "completed", "output": [_image_data_uri()]}))
    image = np.zeros((24, 18, 3), np.uint8)
    engine = FashnApiTryOnEngine("secret", poll_interval_seconds=0)
    engine.apply_garment(image, image, category, np.zeros(image.shape[:2], np.uint8))
    assert len(calls) == 1
    inputs = calls[0]["inputs"]
    assert inputs["generation_mode"] == "quality"
    assert inputs["resolution"] == "1k"
    assert inputs["num_images"] == 1
    assert "existing hijab" in inputs["prompt"]
    assert "Do not expose hair or neck" in inputs["prompt"]
    assert inputs["model_image"].startswith("data:image/png;")


def test_failed_prediction_is_not_resubmitted(monkeypatch):
    calls = []
    monkeypatch.setattr("app.fashn_api.requests.post", lambda *a, **kw:
                        (calls.append(kw) or FakeResponse({"id": "failed"})))
    monkeypatch.setattr("app.fashn_api.requests.get", lambda *a, **kw:
                        FakeResponse({"status": "failed", "error": "Insufficient credits"}))
    image = np.zeros((24, 18, 3), np.uint8)
    with pytest.raises(TryOnUnavailableError, match="Insufficient credits"):
        FashnApiTryOnEngine("secret", poll_interval_seconds=0).apply_outfit(image, image)
    assert len(calls) == 1
