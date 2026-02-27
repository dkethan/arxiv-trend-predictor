from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.api.endpoints import router as app_router
from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)

app = FastAPI(
    title="arxiv-trend-predictor",
    version="0.1.0",
    description="API for advising on tech/arXiv research ideas using arXiv trend data.",
)

# Basic CORS configuration (can be tightened later)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def on_startup() -> None:
    logger.info("Starting arxiv-trend-predictor API on {}:{}", settings.api_host, settings.api_port)


@app.get("/", include_in_schema=False)
async def root() -> dict:
    return {"message": "arxiv-trend-predictor API. See /docs for OpenAPI docs."}


app.include_router(app_router)

