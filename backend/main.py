"""
Application entrypoint for arxiv-trend-predictor.

This file:
- Starts the FastAPI server (host/port taken from config)
- Exposes an HTTP API you can query to get advisor results.

Run:
    python -m backend.main


Then open (host/port from settings):
    - http://<API_HOST>:<API_PORT>/docs     (interactive API docs)
    - POST http://<API_HOST>:<API_PORT>/api/v1/advisor/advise
"""

from __future__ import annotations

import os
import uvicorn
from pathlib import Path


def _load_dotenv() -> None:
    env_path = Path(__file__).resolve().parents[1] / ".env"
    if not env_path.exists():
        return
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip())


_load_dotenv()

from backend.core.config import settings


def run_server() -> None:
    """
    Start the FastAPI server using config-defined host/port.
    Reload is disabled when PORT is set (e.g. on Render) for production.
    """
    uvicorn.run(
        "backend.api.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=not bool(os.environ.get("PORT")),
    )


if __name__ == "__main__":
    run_server()

