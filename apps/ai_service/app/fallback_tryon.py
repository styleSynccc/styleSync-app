"""Fallback wrapper for independently hosted virtual try-on workers."""

import logging
import threading

from .errors import TryOnUnavailableError

LOGGER = logging.getLogger(__name__)


class FallbackTryOnEngine:
    def __init__(self, primary, fallback):
        self.primary = primary
        self.fallback = fallback
        self._request_state = threading.local()

    @property
    def name(self):
        return getattr(self._request_state, "engine_name", self.primary.name)

    def apply_hijab(self, person_bgr, hijab_bgr, hijab_mask):
        try:
            result = self.primary.apply_hijab(person_bgr, hijab_bgr, hijab_mask)
            self._request_state.engine_name = self.primary.name
            return result
        except TryOnUnavailableError:
            result = self.fallback.apply_hijab(person_bgr, hijab_bgr, hijab_mask)
            self._request_state.engine_name = self.fallback.name
            return result

    def apply_garment(self, person_bgr, garment_bgr, category, replace_mask):
        try:
            result = self.primary.apply_garment(
                person_bgr, garment_bgr, category, replace_mask
            )
            self._request_state.engine_name = self.primary.name
            return result
        except TryOnUnavailableError as primary_error:
            LOGGER.warning(
                "%s failed; trying %s: %s",
                self.primary.name,
                self.fallback.name,
                primary_error,
            )
            try:
                result = self.fallback.apply_garment(
                    person_bgr, garment_bgr, category, replace_mask
                )
                self._request_state.engine_name = self.fallback.name
                return result
            except TryOnUnavailableError as fallback_error:
                raise TryOnUnavailableError(
                    f"{self.primary.name} failed: {primary_error.message} "
                    f"Fallback {self.fallback.name} also failed: "
                    f"{fallback_error.message}"
                ) from fallback_error
