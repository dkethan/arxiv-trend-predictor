"""
Application entrypoint for arxiv-trend-predictor.

This file:
- Starts the FastAPI server (host/port taken from config)
- Exposes an HTTP API you can query to get advisor results.

Run:
    python -m backend.main

Then open:
    - http://localhost:8000/docs           (interactive API docs)
    - POST http://localhost:8000/api/v1/advisor/advise
"""

from __future__ import annotations

import uvicorn

from backend.api.main import app  # FastAPI instance
from backend.core.config import settings


def run_server() -> None:
    """
    Start the FastAPI server using config-defined host/port.
    """
    uvicorn.run(
        app,
        host=settings.api_host,
        port=settings.api_port,
        reload=True,
    )


if __name__ == "__main__":
    run_server()

