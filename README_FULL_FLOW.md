# arxiv-trend-predictor

AI-powered advisor and trend analytics for arXiv computer science papers.

> Game on, guys. Watch the game now.

## Wanna implement this?

This is the **main implementation guide** for the project.
If you want a short and quick version, use `README.md`.

### What this project does

- Collects arXiv CS papers (metadata + domain mapping)
- Analyzes temporal trends, keywords, and interdisciplinarity
- Trains a multi-label domain advisor model
- Serves model predictions through FastAPI
- Connects web and mobile apps to the advisor API

### Repository map

- `backend/` - FastAPI app and API services
- `research_pipeline/` - data collection, analysis, model training, evaluation
- `web_app/` - browser client
- `mobile_app/` - Flutter mobile client
- `data/` - pipeline outputs and generated artifacts

## Quick setup

Run from the project root:

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r backend/requirements.txt
cp .env.example .env
```

Default paths:

- `DATA_DIR=./data`
- `MODEL_DIR=./backend/models`

## Full workflow (updated pipeline)

We made many changes after earlier docs, so this flow reflects the current pipeline.

### 1) Collect fresh data

```bash
python -m research_pipeline.scraper.arxiv_scraper
```

### 2) Run analysis

```bash
python -m research_pipeline.analysis.arxiv_analysis
```

### 3) Train and save model artifacts

```bash
python -m research_pipeline.advisor.multi_model_idea_advisor
```

### 4) (Optional) Generate benchmark/evaluation charts

```bash
python -m research_pipeline.advisor.model_evaluation
```

### 5) Upsert similarity records to Pinecone (recommended)

Set Pinecone env vars (`PINECONE_API_KEY`, `PINECONE_INDEX_HOST`, optional `PINECONE_NAMESPACE`) and run:

```bash
python -m research_pipeline.advisor.upsert_similarity_to_pinecone
```

### 6) Start the API

```bash
python -m backend.main
```

### 7) Test the advisor endpoint

```bash
curl -X POST "http://0.0.0.0:60000/api/v1/advisor/advise" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Vision-language model for scientific paper understanding",
    "abstract": "We propose a multimodal method for classifying CS papers into multiple research domains."
  }'
```

### 8) Run clients

- Web app setup: `web_app/README.md`
- Mobile app setup: `mobile_app/README.md`

## Collaborators

1. **Jay Sri (Jayashree Johnson)** - [github.com/jayashreejohnson](https://github.com/jayashreejohnson)
2. **Kamal** - [github.com/kamaldomandula](https://github.com/kamaldomandula)
3. **Kethan Dosapati** - [github.com/dkethan](https://github.com/dkethan)

## Readme index

- `README.md` - simple overview
- `README_FULL_FLOW.md` - full implementation guide (this file)
- `backend/README.md`
- `research_pipeline/README.md`
- `web_app/README.md`
- `mobile_app/README.md`

## License

This project is licensed under the MIT License.
See `LICENSE` for details.
