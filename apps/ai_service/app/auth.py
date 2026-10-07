from fastapi import Header, HTTPException, Request


def _verify(token: str) -> str:
    import firebase_admin
    from firebase_admin import auth as firebase_auth

    if not firebase_admin._apps:
        # Uses GOOGLE_APPLICATION_CREDENTIALS
        firebase_admin.initialize_app()
    return firebase_auth.verify_id_token(token)["uid"]


def current_uid(request: Request, authorization: str | None = Header(default=None)) -> str:
    """Firebase ID token from `Authorization: Bearer <token>` -> uid."""
    if request.app.state.settings.auth_disabled:
        return "dev-user"
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    try:
        return _verify(authorization[len("Bearer "):])
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
