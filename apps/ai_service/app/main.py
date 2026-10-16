import base64
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, File, Form, Request, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from .auth import current_uid
from .config import Settings, get_settings
from .errors import ImageValidationError, PipelineError
from .hijab import HijabAnalyzer, NullHijabAnalyzer
from .pipeline import create_twin
from .storage import (
    LocalResultStore,
    LocalTwinStore,
    LocalWardrobeStore,
    ResultStore,
    TwinStore,
    WardrobeStore,
)
from .tryon import FastFitTryOnEngine, NotImplementedTryOnEngine, TryOnEngine, create_tryon
from .wardrobe import create_wardrobe_item


class TryOnRequest(BaseModel):
    twinId: str
    garmentItemId: str
    # Put the garment on top of this earlier result instead of the bare twin.
    startFromResultId: str | None = None

_CHUNK = 1 << 20
_MULTIPART_OVERHEAD = 1 << 20


async def read_limited(file: UploadFile, limit: int) -> bytes:
    """Read the upload, aborting as soon as it exceeds `limit`."""
    chunks, total = [], 0
    while chunk := await file.read(_CHUNK):
        total += len(chunk)
        if total > limit:
            raise ImageValidationError(f"File too large. Max is {limit / 1_000_000:.0f}MB.")
        chunks.append(chunk)
    return b"".join(chunks)


def create_app(
    *,
    settings: Settings | None = None,
    engine=None,
    hijab_analyzer: HijabAnalyzer | None = None,
    store: TwinStore | None = None,
    wardrobe_store: WardrobeStore | None = None,
    tryon_engine: TryOnEngine | None = None,
    result_store: ResultStore | None = None,
    load_hijab_model: bool = False,
) -> FastAPI:
    settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        if engine is None:
            from .engine import ModelEngine  # loads the models

            app.state.engine = ModelEngine(settings)
        else:
            app.state.engine = engine
        if hijab_analyzer is None and load_hijab_model:
            from .hijab_mediapipe import load_hijab_analyzer

            app.state.hijab_analyzer = load_hijab_analyzer(settings)
        yield

    app = FastAPI(title="StyleSync AI service", lifespan=lifespan)
    app.state.settings = settings
    app.state.hijab_analyzer = hijab_analyzer or NullHijabAnalyzer()
    app.state.store = store or LocalTwinStore(settings.data_dir)
    app.state.wardrobe_store = wardrobe_store or LocalWardrobeStore(settings.data_dir)
    if tryon_engine is None:
        tryon_engine = (
            FastFitTryOnEngine(settings.fastfit_url, settings.fastfit_timeout_s)
            if settings.fastfit_url
            else NotImplementedTryOnEngine()
        )
    app.state.tryon_engine = tryon_engine
    app.state.result_store = result_store or LocalResultStore(settings.data_dir)

    if settings.cors_allow_all:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_methods=["*"],
            allow_headers=["*"],
        )

    @app.middleware("http")
    async def reject_oversized(request: Request, call_next):
        length = request.headers.get("content-length")
        if length and length.isdigit() and int(length) > settings.max_upload_bytes + _MULTIPART_OVERHEAD:
            return JSONResponse(
                status_code=413,
                content={"success": False, "error_type": "PAYLOAD_TOO_LARGE",
                         "message": "Upload is too large."},
            )
        return await call_next(request)

    @app.exception_handler(PipelineError)
    async def pipeline_error_handler(request: Request, exc: PipelineError):
        body = {"success": False, "error_type": exc.code, "message": exc.message}
        if reason := getattr(exc, "reason", None):
            body["reason"] = reason
        return JSONResponse(status_code=exc.status_code, content=body)

    @app.get("/health")
    def health():
        return {"status": "AI server is running"}

    @app.post("/v1/twins", status_code=201)
    async def post_twin(
        request: Request,
        file: UploadFile = File(...),
        uid: str = Depends(current_uid),
    ):
        raw = await read_limited(file, settings.max_upload_bytes)
        # Heavy CPU work: keep it off the event loop.
        result = await run_in_threadpool(
            create_twin,
            raw,
            uid,
            engine=request.app.state.engine,
            hijab_analyzer=request.app.state.hijab_analyzer,
            store=request.app.state.store,
            settings=settings,
        )
        return result.to_response()

    @app.get("/v1/twins")
    async def get_twins(request: Request, uid: str = Depends(current_uid)):
        twins = request.app.state.store.list(uid)
        return {
            "success": True,
            "twins": [
                {
                    "twinId": t.metadata.get("twinId"),
                    "metadata": t.metadata,
                    "personImageB64": base64.b64encode(t.processed_jpg).decode(),
                }
                for t in twins
            ],
        }

    @app.post("/v1/wardrobe", status_code=201)
    async def post_wardrobe_item(
        request: Request,
        file: UploadFile = File(...),
        category: str = Form(...),
        uid: str = Depends(current_uid),
    ):
        raw = await read_limited(file, settings.max_upload_bytes)
        result = await run_in_threadpool(
            create_wardrobe_item,
            raw,
            uid,
            category,
            engine=request.app.state.engine,
            store=request.app.state.wardrobe_store,
            settings=settings,
        )
        return result.to_response()

    @app.get("/v1/wardrobe")
    async def get_wardrobe(request: Request, uid: str = Depends(current_uid)):
        items = request.app.state.wardrobe_store.list(uid)
        return {
            "success": True,
            "items": [
                {
                    "itemId": i.metadata.get("itemId"),
                    "metadata": i.metadata,
                    "itemImageB64": base64.b64encode(i.processed_jpg).decode(),
                }
                for i in items
            ],
        }

    @app.post("/v1/tryon", status_code=201)
    async def post_tryon(
        request: Request,
        body: TryOnRequest,
        uid: str = Depends(current_uid),
    ):
        result = await run_in_threadpool(
            create_tryon,
            uid,
            body.twinId,
            body.garmentItemId,
            body.startFromResultId,
            twin_store=request.app.state.store,
            wardrobe_store=request.app.state.wardrobe_store,
            tryon_engine=request.app.state.tryon_engine,
            result_store=request.app.state.result_store,
            settings=settings,
        )
        return result.to_response()

    return app


app = create_app(load_hijab_model=True)
