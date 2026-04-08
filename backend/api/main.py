from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api.endpoints import router as app_router
from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logger.info(
        "Starting arxiv-trend-predictor API on {}:{}",
        settings.api_host,
        settings.api_port,
    )
    logger.info(
        "Pinecone configured: api_key={} index_host={}",
        "SET" if settings.pinecone_api_key else "MISSING",
        settings.pinecone_index_host or "MISSING",
    )
    yield


app = FastAPI(
    title="arxiv-trend-predictor",
    version="0.1.0",
    description="API for advising on tech/arXiv research ideas using arXiv trend data.",
    lifespan=lifespan,
)

# Basic CORS configuration (can be tightened later)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/", include_in_schema=False)
async def root() -> dict:
    return {"message": "arxiv-trend-predictor API. See /docs for OpenAPI docs."}


app.include_router(app_router)

