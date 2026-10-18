from app.config import Settings
from app.fashn_worker import FashnWorkerTryOnEngine
from app.main import build_tryon_engine


def test_fashn_is_the_only_default_engine():
    engine = build_tryon_engine(Settings())
    assert isinstance(engine, FashnWorkerTryOnEngine)
    assert not engine.shoe_engine.configured


def test_fashn_api_key_enables_hosted_shoe_engine():
    engine = build_tryon_engine(Settings(fashn_api_key="secret"))
    assert isinstance(engine, FashnWorkerTryOnEngine)
    assert engine.shoe_engine.configured
    assert engine.name == "fashn-vton-1.5+fashn-tryon-max"


def test_skirt_uses_local_bottoms_engine(monkeypatch):
    import cv2
    import numpy as np
    import requests

    image = np.full((64, 48, 3), 120, np.uint8)
    calls = []

    def post(url, **kwargs):
        assert kwargs["data"]["num_timesteps"] == "30"
        assert kwargs["data"]["guidance_scale"] == "3.0"
        assert kwargs["data"]["seed"] == "7"
        assert kwargs["data"]["verify_skirt"] == "true"
        calls.append((url, kwargs["data"]["category"], kwargs["data"]["segmentation_free"]))
        response = requests.Response()
        response.status_code = 200
        response._content = cv2.imencode(".jpg", image)[1].tobytes()
        return response

    monkeypatch.setattr(requests, "post", post)
    engine = FashnWorkerTryOnEngine("http://worker")
    result = engine.apply_garment(image, image, "Skirts", np.zeros((64, 48), np.uint8))
    assert result.shape == image.shape
    assert calls == [("http://worker/generate", "bottoms", "false")]
