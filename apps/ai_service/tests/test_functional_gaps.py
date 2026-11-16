"""Missing functional guards; isolated FastAPI calls, fake AI, temporary filesystem only."""
from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image

from tests.test_inspo_api import InspoEngine, make_app, reference_photo
from tests.test_list_endpoints import seed_twin
from tests.test_pipeline_api import make_client
from tests.conftest import FakeEngine, standing_landmarks


def test_TC007_missing_twin_photo_is_schema_error_and_saves_nothing(tmp_path):
    with make_client(tmp_path, FakeEngine(standing_landmarks())) as client:
        response = client.post('/v1/twins')
    assert response.status_code == 422
    assert response.json()['detail'][0]['loc'] == ['body', 'file']
    assert not (tmp_path / 'twins').exists()


def test_TC013_missing_category_is_schema_error_and_saves_nothing(tmp_path, photo_bytes):
    with make_client(tmp_path, FakeEngine()) as client:
        response = client.post('/v1/wardrobe', files={'file': ('item.jpg', photo_bytes, 'image/jpeg')})
    assert response.status_code == 422
    assert response.json()['detail'][0]['loc'] == ['body', 'category']
    assert not (tmp_path / 'wardrobe').exists()


def test_TC026_absent_twin_rejects_before_provider_or_result_save(tmp_path):
    engine = InspoEngine()
    with TestClient(make_app(tmp_path, engine)) as client:
        response = client.post('/v1/inspo', data={'twinId': 'missing'},
                               files={'file': ('reference.jpg', reference_photo(), 'image/jpeg')})
    assert response.status_code == 404
    assert response.json()['error_type'] == 'TWIN_NOT_FOUND'
    assert engine.calls == 0
    assert not (tmp_path / 'results').exists()


def test_TC023_svg_reference_is_rejected_before_provider_or_result_save(tmp_path):
    seed_twin(tmp_path, 'mine', '2026-01-01')
    engine = InspoEngine()
    svg = b'<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800"><rect width="600" height="800"/></svg>'
    with TestClient(make_app(tmp_path, engine)) as client:
        response = client.post('/v1/inspo', data={'twinId': 'mine'},
                               files={'file': ('reference.svg', svg, 'image/svg+xml')})
    assert response.status_code == 400
    assert response.json()['error_type'] == 'INVALID_IMAGE'
    assert engine.calls == 0
    assert not (tmp_path / 'results').exists()


def test_TC027_low_resolution_reference_is_rejected_before_provider(tmp_path):
    seed_twin(tmp_path, 'mine', '2026-01-01')
    engine = InspoEngine()
    image = BytesIO()
    Image.new('RGB', (120, 160), 'gray').save(image, format='JPEG')
    with TestClient(make_app(tmp_path, engine)) as client:
        response = client.post('/v1/inspo', data={'twinId': 'mine'},
                               files={'file': ('tiny.jpg', image.getvalue(), 'image/jpeg')})
    assert response.status_code == 400
    assert 'too small' in response.json()['message']
    assert engine.calls == 0
    assert not (tmp_path / 'results').exists()


def test_TC027_characterization_blank_decodable_reference_reaches_fake_provider(tmp_path):
    """Record current behavior, not proof that an unsuitable scene is rejected."""
    seed_twin(tmp_path, 'mine', '2026-01-01')
    engine = InspoEngine()
    with TestClient(make_app(tmp_path, engine)) as client:
        response = client.post('/v1/inspo', data={'twinId': 'mine'},
                               files={'file': ('blank.jpg', reference_photo(), 'image/jpeg')})
    assert response.status_code == 201
    assert engine.calls == 1  # No person/garment suitability check precedes the provider.
    assert response.json()['metadata']['source'] == 'inspo'
