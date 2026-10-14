import logging
import time

from fastapi import Header, HTTPException, Request

logger = logging.getLogger(__name__)


def _verify(token: str, project_id: str) -> str:
    from google.auth.transport.requests import Request as GoogleRequest
    from google.oauth2 import id_token as google_id_token

    claims = google_id_token.verify_firebase_token(
        token,
        GoogleRequest(),
        audience=project_id,
    )

    expected_issuer = f"https://securetoken.google.com/{project_id}"
    if claims.get("iss") != expected_issuer:
        raise ValueError("Firebase token has an invalid issuer")

    uid = claims.get("sub")
    if not isinstance(uid, str) or not uid or len(uid) > 128:
        raise ValueError("Firebase token has an invalid subject")

    auth_time = claims.get("auth_time")
    if not isinstance(auth_time, (int, float)) or auth_time > time.time():
        raise ValueError("Firebase token has an invalid authentication time")

    return uid


def current_uid(request: Request, authorization: str | None = Header(default=None)) -> str:
    """Firebase ID token from `Authorization: Bearer <token>` -> uid."""
    if request.app.state.settings.auth_disabled:
        return "dev-user"
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    try:
        return _verify(
            authorization[len("Bearer "):],
            request.app.state.settings.firebase_project_id,
        )
    except Exception as exc:
        logger.warning("Firebase token verification failed: %s", exc)
        raise HTTPException(status_code=401, detail="Invalid or expired token")
