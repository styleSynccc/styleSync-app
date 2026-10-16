from app.config import Settings
from app.fashn_worker import FashnWorkerTryOnEngine
from app.main import build_tryon_engine


def test_fashn_is_the_only_default_engine():
    engine = build_tryon_engine(Settings())
    assert isinstance(engine, FashnWorkerTryOnEngine)
    assert not engine.shoe_engine.configured


def test_fashn_api_key_enables_hosted_shoe_engine():
    engine = build_tryon_engine(Settings(fashn_api_key="secret"))
    assert isinstance(engine, FashnWorkerTryOnEngine)
    assert engine.shoe_engine.configured
    assert engine.name == "fashn-vton-1.5+fashn-tryon-max"
