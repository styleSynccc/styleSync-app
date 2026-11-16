"""Request-to-storage-to-retrieval workflows missing from the seeded-list tests.

FastAPI and filesystem storage are real. Authentication and image models are fake;
all artifacts remain in pytest's temporary directory. No provider/network calls.
"""
import base64

from fastapi.testclient import TestClient

from app.auth import current_uid
from app.config import Settings
from app.main import create_app
from tests.conftest import FakeEngine, standing_landmarks


def isolated_app(tmp_path, uid):
    app = create_app(settings=Settings(data_dir=tmp_path, auth_disabled=False),
                     engine=FakeEngine(standing_landmarks()))
    app.dependency_overrides[current_uid] = lambda: uid
    return app


def test_TC007_TC009_created_twin_survives_app_restart_and_stays_user_scoped(tmp_path, photo_bytes):
    with TestClient(isolated_app(tmp_path, 'qa-owner')) as client:
        created = client.post('/v1/twins', files={'file': ('body.jpg', photo_bytes, 'image/jpeg')})
    assert created.status_code == 201
    twin = created.json()
    # A new application/store instance must discover the saved result, not a seed.
    with TestClient(isolated_app(tmp_path, 'qa-owner')) as client:
        response = client.get('/v1/twins')
    assert response.status_code == 200
    assert [item['twinId'] for item in response.json()['twins']] == [twin['twinId']]
    assert response.json()['twins'][0]['personImageB64'] == twin['personImageB64']
    assert base64.b64decode(twin['personImageB64']).startswith(b'\xff\xd8')
    with TestClient(isolated_app(tmp_path, 'qa-other')) as client:
        assert client.get('/v1/twins').json()['twins'] == []


def test_TC010_TC013_uploaded_category_and_processed_image_survive_app_restart(tmp_path, photo_bytes):
    with TestClient(isolated_app(tmp_path, 'qa-owner')) as client:
        created = client.post('/v1/wardrobe', data={'category': 'Pants'},
                              files={'file': ('pants.jpg', photo_bytes, 'image/jpeg')})
    assert created.status_code == 201
    item = created.json()
    with TestClient(isolated_app(tmp_path, 'qa-owner')) as client:
        response = client.get('/v1/wardrobe')
    assert response.status_code == 200
    listed = response.json()['items']
    assert [record['itemId'] for record in listed] == [item['itemId']]
    assert listed[0]['metadata']['category'] == 'Pants'
    assert listed[0]['itemImageB64'] == item['itemImageB64']
    with TestClient(isolated_app(tmp_path, 'qa-other')) as client:
        assert client.get('/v1/wardrobe').json()['items'] == []
