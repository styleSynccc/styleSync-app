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

    assert result.shape == person.shape
    assert submitted["json"]["model_name"] == "tryon-max"
    inputs = submitted["json"]["inputs"]
    assert inputs["return_base64"] is True
    assert inputs["generation_mode"] == "fast"
    assert submitted["headers"]["Authorization"] == "Bearer secret"
