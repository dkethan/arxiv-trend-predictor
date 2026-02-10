## Using the Idea Advisor model

This document explains the full flow:

1. **Collect data** with the scraper.
2. **Run analysis** to generate trend stats.
3. **Train the model**.
4. **Serve it** via the FastAPI backend.

All CLI steps are run from the **repo root**.

### 1. Collect arXiv data

Use the scraper in the research pipeline:

```bash
python -m research_pipeline.scraper.arxiv_scraper
```

This writes CSV/JSON + stats into:

- `data/arxiv_data/`

### 2. Run analysis

Generate temporal trends, keywords, clustering, and interdisciplinary metrics:

```bash
python -m research_pipeline.analysis.arxiv_analysis
```

This writes:

- `data/analysis_output/analysis_results.json`
- Optional plots under `data/analysis_output/` (if plotting deps are installed).

### 3. Train the Idea Advisor model

Train from the latest CSV in `data/arxiv_data/`:

```bash
python -m research_pipeline.scripts.run_advisor train
```

This saves model artifacts under the backend’s model directory (see `backend/core/config.py`):

- `domain_vectorizer.pkl`
- `domain_classifier.pkl`

### 4. Use the model from the CLI

After training, you can query the advisor directly:

```bash
python -m research_pipeline.scripts.run_advisor advise \
  "Your idea title goes here" \
  "Optional longer abstract / description goes here"
```

You’ll see:

- Predicted **domain**
- **Trend** score/label for that domain
- Suggested **keywords**
- A short **message** explaining the advice

### 5. Use the model via HTTP

Start the backend:

```bash
python -m backend.main
```

Then call the advisor over HTTP (host/port from settings – `API_HOST`, `API_PORT`):

```bash
curl -X POST http://$API_HOST:$API_PORT/api/v1/advisor/advise \
  -H "Content-Type: application/json" \
  -d '{
        "title": "Your idea title goes here",
        "abstract": "Optional longer abstract / description goes here"
      }'
```

### 6. Environment and paths

Key environment variables (see `backend/core/config.py`):

- `DATA_DIR` – base directory for data (default: `./data`).
- `MODEL_DIR` – directory for saved models (default: `./backend/models` via config).
- `API_HOST` / `API_PORT` – where the FastAPI app binds.

