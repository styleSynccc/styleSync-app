import cv2
import numpy as np
import pytest
import requests

from app.errors import GarmentExtractionError, NoGarmentError
from app.garment_extraction import GarmentExtractor


@pytest.mark.parametrize("status,error", [(422, NoGarmentError), (503, GarmentExtractionError)])
def test_worker_errors(monkeypatch, status, error):
    response = requests.Response()
    response.status_code = status
    monkeypatch.setattr(requests, "post", lambda *args, **kwargs: response)
    with pytest.raises(error):
        GarmentExtractor("http://worker").mask(np.zeros((40, 30, 3), np.uint8), "Tops")


def test_worker_connection_failure(monkeypatch):
    def fail(*args, **kwargs):
        raise requests.ConnectionError()
    monkeypatch.setattr(requests, "post", fail)
    with pytest.raises(GarmentExtractionError):
        GarmentExtractor("http://worker").mask(np.zeros((40, 30, 3), np.uint8), "Pants")


@pytest.mark.parametrize("status,shape", [(204, None), (200, (40, 30)), (200, (10, 10))])
def test_worker_mask_response(monkeypatch, status, shape):
    response = requests.Response()
    response.status_code = status
    if shape:
        response._content = cv2.imencode(".png", np.full(shape, 255, np.uint8))[1].tobytes()
    monkeypatch.setattr(requests, "post", lambda *args, **kwargs: response)
    extractor = GarmentExtractor("http://worker")
    image = np.zeros((40, 30, 3), np.uint8)
    if shape == (10, 10):
        with pytest.raises(GarmentExtractionError):
            extractor.mask(image, "Tops")
    elif status == 204:
        assert extractor.mask(image, "Tops") is None
    else:
        assert (extractor.mask(image, "Tops") == 255).all()
