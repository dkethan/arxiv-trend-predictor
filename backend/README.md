## arxiv-trend-predictor backend

This is the **backend** (Web API) component. Commands to run the API are run from the **project root** (the folder that contains `backend/`, `web_app/`, etc.). If you are inside `backend/`, go to the project root with: `cd ..` (or `cd ../..` if you were in a subfolder of `backend`).

FastAPI backend that serves the trained Idea Advisor model over HTTP.

- **Does**: load models, expose `/health`, `/health/ready`, and `/api/v1/advisor/...` endpoints.
- **Does not**: run scraping or analysis itself – those live in the `research_pipeline/` package.

### Run the API server

From the project root (after installing dependencies):

```bash
python -m backend.main
```

Host and port come from settings only (`API_HOST`, `API_PORT` in `.env`; see `backend/core/config.py`).

Key endpoints:

- `GET /health` – liveness.
- `GET /health/ready` – readiness (checks model + analysis files).
- `POST /api/v1/advisor/advise` – Idea Advisor.

Interactive docs:

- Open `http://<API_HOST>:<API_PORT>/docs` in your browser (use the values from your settings).

### Deploying to Render

1. **Push your repo to GitHub** (or GitLab) and ensure the root contains `render.yaml`; backend deps are in `backend/requirements.txt`.

2. **In [Render Dashboard](https://dashboard.render.com)** → **New** → **Blueprint**. Connect the repo; Render will detect `render.yaml` and create the web service.

3. **Or create a Web Service manually**: **New** → **Web Service**, connect the repo, then set:
   - **Build command:** `pip install -r backend/requirements.txt`
   - **Start command:** `python -m backend.main`
   - **Health check path:** `/health` (optional; enables zero-downtime deploys)

4. **Environment variables** (optional): In the service **Environment** tab, add any of:
   - `LOG_LEVEL`, `DATA_DIR`, `MODEL_DIR`, `ARXIV_START_YEAR`, `ARXIV_END_YEAR`, `PAPERS_PER_CATEGORY_PER_YEAR`, `ENABLE_ANALYSIS_EMBEDDINGS`, `ENABLE_PLOTTING`
   - `SIMILARITY_TOP_K`, `PINECONE_API_KEY`, `PINECONE_INDEX_HOST`, `PINECONE_NAMESPACE`, `PINECONE_TEXT_FIELD`, `PINECONE_API_VERSION`, `PINECONE_TIMEOUT_SECONDS`
   See `.env.example` in the repo root. Render sets `PORT` automatically; the app uses it when present.

Similarity retrieval is Pinecone-backed. If Pinecone is not configured or temporarily unavailable, the API returns `similar_papers: []` and a `similarity_note` message.

5. **Deploy**: Render builds and deploys on each push to the linked branch. The API will be at `https://<service-name>.onrender.com` (e.g. `/docs`, `/health`, `/api/v1/advisor/advise`).
