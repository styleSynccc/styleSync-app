"""Require the app's displayed quote before starting any paid generation."""
from .errors import CreditConfirmationError, TryOnUnavailableError


def confirm_generation_cost(engine, count: int, confirmed: int | None) -> int:
    credits = getattr(engine, "credits_per_image", 0) * count
    if getattr(engine, "configured", True) is False:
        raise TryOnUnavailableError(
            "Try-On Max needs a FASHN API key. Set FASHN_API_KEY on the server, then restart it."
        )
    if credits and (type(confirmed) is not int or confirmed != credits):
        raise CreditConfirmationError(
            f"This generation requires confirmation for {credits} API credits. "
            "Update or refresh the app, review the cost, and confirm before generating."
        )
    return credits
