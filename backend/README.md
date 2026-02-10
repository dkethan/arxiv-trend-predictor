## arxiv-trend-predictor backend

FastAPI backend that serves the trained Idea Advisor model over HTTP.

- **Does**: load models, expose `/health`, `/health/ready`, and `/api/v1/advisor/...` endpoints.
- **Does not**: run scraping or analysis itself – those live in the `research_pipeline/` package.

### Run the API server

From the repo root (after installing dependencies):

```bash
python -m backend.main
```

This uses `API_HOST` and `API_PORT` from `.env` (defaults to `0.0.0.0:8000`).

Key endpoints:

- `GET /health` – liveness.
- `GET /health/ready` – readiness (checks model + analysis files).
- `POST /api/v1/advisor/advise` – Idea Advisor.

Interactive docs:

- Open `http://localhost:8000/docs` in your browser.
