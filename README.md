## arxiv-trend-predictor

Idea Advisor and analysis tools for arXiv tech papers (scraper, analysis, model training, and an HTTP API).

### Project structure

- `backend/` – FastAPI service that serves the trained model and exposes HTTP APIs
- `research_pipeline/` – scraping, analysis, and training pipeline
- `web_app/` – future web client, will consume the backend API
- `mobile_app/` – future mobile client, will consume the backend API

---

## Prerequisites

```bash
# 1) Create and activate a virtualenv (optional but recommended)
python -m venv .venv
source .venv/bin/activate  # on Windows: .venv\Scripts\activate

# 2) Install dependencies
pip install -r requirements.txt

# 3) Create your .env from the example
cp .env.example .env
```

By default:
- `DATA_DIR` → `./data`
- `MODEL_DIR` → `./backend/models`

---

## Step-by-step workflow

### Step 1: Get your data and train the model

**What to do:** Check if you already have data and trained models. If not, run the research pipeline.

**How to check:**
- Look for `data/arxiv_data/*.csv` files
- Look for `data/analysis_output/analysis_results.json`
- Look for model files: `backend/models/domain_vectorizer.pkl` and `backend/models/domain_classifier.pkl`

**If you don't have these files:**

Go to **[research_pipeline/README.md](research_pipeline/README.md)** and follow all the steps there:

1. Run the scraper to collect arXiv data
2. Run the analysis to generate trends
3. Train the model

**Verify Step 1 is complete:**
- You should have CSV files in `data/arxiv_data/`
- You should have `data/analysis_output/analysis_results.json`
- You should have `backend/models/domain_vectorizer.pkl` and `backend/models/domain_classifier.pkl`

Once verified, proceed to Step 2.

---

### Step 2: Start the backend API server

**What to do:** Start the FastAPI backend server so you can query the model via HTTP.

**How to do it:**

Go to **[backend/README.md](backend/README.md)** and follow the instructions to start the server:

```bash
python -m backend.main
```

**Verify Step 2 is complete:**

1. The server should start without errors
2. Test the health endpoint (use `API_HOST` and `API_PORT` from your `.env` / settings):
   ```bash
   curl http://$API_HOST:$API_PORT/health
   ```
   Should return: `{"status": "ok"}`

3. Test the readiness endpoint:
   ```bash
   curl http://$API_HOST:$API_PORT/health/ready
   ```
   Should return readiness status with model file checks

4. Open the interactive docs:
   - Go to `http://<API_HOST>:<API_PORT>/docs` in your browser (values from settings)
   - You should see the Swagger UI with available endpoints

**For more details on endpoints and usage:**
- See [backend/README.md](backend/README.md) for API documentation
- See [backend/MODEL_USAGE.md](backend/MODEL_USAGE.md) for detailed model usage guide

Once the server is running and you've verified the endpoints work, proceed to Step 3.

---

### Step 3: Use the API

**What to do:** Test the API by making requests to the advisor endpoint.

**Example request:**

```bash
curl -X POST http://$API_HOST:$API_PORT/api/v1/advisor/advise \
  -H "Content-Type: application/json" \
  -d '{
        "title": "Your idea title",
        "abstract": "Optional longer description..."
      }'
```
(Use `API_HOST` and `API_PORT` from your settings.)

**Verify Step 3 is complete:**
- You should get a JSON response with `domain`, `domain_confidence`, `suggested_keywords`, etc.

---

### Step 4: Build web and mobile clients (future)

**What to do:** Build UI clients that call the backend API.

**How to do it:**

- For web app: See [web_app/README.md](web_app/README.md)
- For mobile app: See [mobile_app/README.md](mobile_app/README.md)

Both will consume the backend API endpoints (mainly `/api/v1/advisor/advise`).

---

## Documentation links

- [backend/README.md](backend/README.md) – Backend API documentation
- [backend/MODEL_USAGE.md](backend/MODEL_USAGE.md) – Detailed model usage guide
- [research_pipeline/README.md](research_pipeline/README.md) – Research pipeline overview
- [web_app/README.md](web_app/README.md) – Web app (future)
- [mobile_app/README.md](mobile_app/README.md) – Mobile app (future)
