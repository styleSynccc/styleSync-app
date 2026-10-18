import io
from types import SimpleNamespace

import numpy as np
import pytest
from fastapi.testclient import TestClient
from PIL import Image

import worker
from garment_extraction import garment_mask


@pytest.mark.parametrize("category,label", [("Tops", 3), ("Pants", 6), ("Skirts", 5)])
def test_keeps_only_selected_garment(category, label):
    labels = np.repeat(np.arange(18, dtype=np.uint8)[:, None], 100, axis=1)
    mask = garment_mask(labels, category)
    assert mask is not None
    assert (mask[labels == label] == 255).all()
    assert (mask[labels != label] == 0).all()


def test_product_photo_uses_background_removal():
    labels = np.full((100, 100), 3, np.uint8)
    assert garment_mask(labels, "Tops") is None


def test_keeps_separate_pant_legs_but_removes_label_specks():
    labels = np.zeros((100, 100), np.uint8)
    labels[:10] = 1  # face
    labels[30:90, 20:40] = 6
    labels[30:90, 60:80] = 6
    labels[95, 95] = 6
    mask = garment_mask(labels, "Pants")
    assert (mask[30:90, 20:40] == 255).all()
    assert (mask[30:90, 60:80] == 255).all()
    assert mask[95, 95] == 0


@pytest.mark.parametrize("result,status", [
    (None, 204),
    (np.zeros((100, 100), np.uint8), 422),
    (np.full((100, 100), 255, np.uint8), 200),
])
def test_extraction_endpoint(monkeypatch, result, status):
    monkeypatch.setattr(worker.runner, "extract_garment", lambda image, category: result)
    image = io.BytesIO()
    Image.new("RGB", (100, 100)).save(image, "PNG")
    with TestClient(worker.app) as client:
        response = client.post("/extract-garment", files={"image": ("photo.png", image.getvalue())},
                               data={"category": "Tops"})
    assert response.status_code == status
    if status == 200:
        assert np.array_equal(np.array(Image.open(io.BytesIO(response.content))), result)


@pytest.mark.parametrize("mode,expected", [("false", False), ("true", True)])
def test_generation_passes_masking_choice_to_pipeline(monkeypatch, mode, expected):
    calls = []

    def generate(person, garment, category, photo_type, seed, segmentation_free, num_timesteps, guidance_scale, verify_skirt):
        calls.append(segmentation_free)
        return person

    monkeypatch.setattr(worker.runner, "generate", generate)
    image = io.BytesIO()
    Image.new("RGB", (100, 100)).save(image, "PNG")
    with TestClient(worker.app) as client:
        response = client.post("/generate", files={
            "person": ("person.png", image.getvalue()),
            "garment": ("skirt.png", image.getvalue()),
        }, data={"category": "bottoms", "segmentation_free": mode})
    assert response.status_code == 200
    assert calls == [expected]


@pytest.mark.parametrize("labels,expected_seeds", [([5], [7]), ([6, 5], [7, 8]), ([6, 6], [7, 8])])
def test_skirt_generation_retries_and_rejects_wrong_clothing(labels, expected_seeds):
    image = Image.new("RGB", (100, 100))
    seeds = []
    predictions = iter(labels)

    def predict(result):
        segmentation = np.full((100, 100), next(predictions), np.uint8)
        segmentation[:20] = 1  # face, so the detector recognizes a person
        return segmentation

    class Pipeline:
        hp_model = SimpleNamespace(predict=predict)

        def __call__(self, **kwargs):
            seeds.append(kwargs["seed"])
            return SimpleNamespace(images=[image])

    runner = worker.FashnRunner()
    runner._pipeline = Pipeline()
    runner._torch = SimpleNamespace(cuda=SimpleNamespace(
        OutOfMemoryError=MemoryError, empty_cache=lambda: None,
    ))
    if labels[-1] == 6:
        with pytest.raises(RuntimeError, match="could not reproduce this skirt"):
            runner.generate(image, image, "bottoms", "flat-lay", 7, verify_skirt=True)
    else:
        assert runner.generate(image, image, "bottoms", "flat-lay", 7, verify_skirt=True).size == image.size
    assert seeds == expected_seeds
