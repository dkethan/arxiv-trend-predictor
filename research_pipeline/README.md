## research_pipeline

This is the **research_pipeline** component (data collection, analysis, model training). All pipeline commands must be run from the **project root** (the folder that contains `research_pipeline/`, `backend/`, etc.). If you are inside `research_pipeline/`, go to the project root with: `cd ..`.

Research pipeline for arxiv-trend-predictor: data collection, analysis, and model training.

This package contains all the offline/experimental components:

- **scraper/**: arXiv data collection
- **analysis/**: Trend analysis and statistics
- **advisor/**: Model training and inference logic
- **scripts/**: CLI utilities for running the pipeline

### Quick start

All commands run from the **project root**:

1. **Collect data**:
   ```bash
   python -m research_pipeline.scraper.arxiv_scraper
   ```

2. **Run analysis**:
   ```bash
   python -m research_pipeline.analysis.arxiv_analysis
   ```

3. **Train model**:
   ```bash
   python -m research_pipeline.scripts.run_advisor train
   ```

4. **Use model** (CLI):
   ```bash
   python -m research_pipeline.scripts.run_advisor advise "Title" "Abstract"
   ```

The trained models are saved to `backend/models/` and can be served via the FastAPI backend.

See `backend/MODEL_USAGE.md` for detailed documentation.
