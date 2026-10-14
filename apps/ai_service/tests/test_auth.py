import time
from unittest.mock import patch

import pytest

from app.auth import _verify


PROJECT_ID = "stylesync-app-3d7c1"


def _claims(**overrides):
    claims = {
        "iss": f"https://securetoken.google.com/{PROJECT_ID}",
        "sub": "firebase-user-123",
        "auth_time": time.time() - 10,
    }
    claims.update(overrides)
    return claims


@patch("google.oauth2.id_token.verify_firebase_token")
def test_verify_returns_firebase_uid(verify_token):
    verify_token.return_value = _claims()

    assert _verify("signed-token", PROJECT_ID) == "firebase-user-123"
    assert verify_token.call_args.kwargs["audience"] == PROJECT_ID


@pytest.mark.parametrize(
    "claims",
    [
        _claims(iss="https://securetoken.google.com/a-different-project"),
        _claims(sub=""),
        _claims(sub="x" * 129),
        _claims(auth_time=time.time() + 3600),
    ],
)
@patch("google.oauth2.id_token.verify_firebase_token")
def test_verify_rejects_invalid_firebase_claims(verify_token, claims):
    verify_token.return_value = claims

    with pytest.raises(ValueError):
        _verify("signed-token", PROJECT_ID)
