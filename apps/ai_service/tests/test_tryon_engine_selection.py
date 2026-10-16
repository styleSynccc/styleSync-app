import numpy as np
import pytest

from app.catvton_worker import CatVTONWorkerTryOnEngine
from app.config import Settings
from app.errors import TryOnUnavailableError
from app.fallback_tryon import FallbackTryOnEngine
from app.fashn_worker import FashnWorkerTryOnEngine
from app.main import build_tryon_engine


class StubEngine:
    def __init__(self, name, *, fails=False):
        self.name = name
        self.fails = fails

    def apply_garment(self, person, garment, category, mask):
        if self.fails:
            raise TryOnUnavailableError(f"{self.name} unavailable")
        return person


def test_fashn_is_the_only_default_engine():
    engine = build_tryon_engine(Settings())
    assert isinstance(engine, FashnWorkerTryOnEngine)
    assert not engine.shoe_engine.configured


def test_fashn_api_key_enables_hosted_shoe_engine():
    engine = build_tryon_engine(Settings(fashn_api_key="secret"))
    assert isinstance(engine, FashnWorkerTryOnEngine)
    assert engine.shoe_engine.configured
    assert engine.name == "fashn-vton-1.5+fashn-tryon-max"


def test_engine_can_be_forced_without_fallback():
    engine = build_tryon_engine(
        Settings(tryon_engine="catvton", tryon_fallback_engine="")
    )
    assert isinstance(engine, CatVTONWorkerTryOnEngine)


def test_invalid_engine_configuration_is_rejected():
    with pytest.raises(ValueError, match="TRYON_ENGINE"):
        build_tryon_engine(Settings(tryon_engine="unknown"))


def test_fallback_records_the_engine_that_created_the_result():
    engine = FallbackTryOnEngine(
        StubEngine("primary", fails=True), StubEngine("fallback")
    )
    image = np.zeros((4, 4, 3), np.uint8)
    mask = np.zeros((4, 4), np.uint8)
    engine.apply_garment(image, image, "Tops", mask)
    assert engine.name == "fallback"
