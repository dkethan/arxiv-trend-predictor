# research_pipeline

Updated research/data pipeline for `arxiv-trend-predictor`.

Run every command from the **project root** (the folder containing `backend/`, `research_pipeline/`, `web_app/`, and `mobile_app/`).

## What is inside

- `scraper/` - collects arXiv paper metadata
- `analysis/` - temporal trends, keywords, interdisciplinarity, optional clustering
- `advisor/` - multi-label model training, inference, benchmark, evaluation plots

## Current pipeline flow

### 1) Collect data

```bash
python -m research_pipeline.scraper.arxiv_scraper
```

Expected output:

- CSV/JSON files in `data/arxiv_data/`

### 2) Run analysis

```bash
python -m research_pipeline.analysis.arxiv_analysis
```

Expected output:

- `data/analysis_output/analysis_results.json`
- analysis charts in `data/analysis_output/` (when plotting is enabled)

### 3) Train advisor model

```bash
python -m research_pipeline.advisor.multi_model_idea_advisor
```

Expected output in `backend/models/`:

- `domain_classifier.pkl`
- `label_binarizer.pkl`
- `model_meta.json`
- `benchmark_results.json`
- `temporal_trends.json` and `temporal_trends.pkl`
- `domain_vectorizer.pkl` (when TF-IDF model wins)
- `sbert_model_name.pkl` (when SciBERT model wins)

### 4) Generate evaluation report (optional but recommended)

```bash
python -m research_pipeline.advisor.model_evaluation
```

Expected output:

- charts and report in `data/analysis_output/evaluation/`

### 5) Upsert similarity records to Pinecone (for API similar papers)

Set `PINECONE_API_KEY`, `PINECONE_INDEX_HOST`, and optional `PINECONE_NAMESPACE`, then run:

```bash
python -m research_pipeline.advisor.upsert_similarity_to_pinecone
```

Notes:

- This pushes title/abstract text and metadata to Pinecone for advisor similarity retrieval.
- `research_pipeline.advisor.build_similarity_index` is now deprecated for runtime API usage.

## Quick verification checklist

- Data exists in `data/arxiv_data/`
- Analysis file exists at `data/analysis_output/analysis_results.json`
- Trained model files exist in `backend/models/`
- API can read model files (`python -m backend.main`, then check `/health/ready`)

## Notes

- The old `research_pipeline/scripts/run_advisor` flow is no longer the active command path.
- Use module entrypoints shown above for the latest pipeline behavior.
