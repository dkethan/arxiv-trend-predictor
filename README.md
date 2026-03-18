# arxiv-trend-predictor

Simple overview of the project.

Full guide: [README_FULL_FLOW.md](README_FULL_FLOW.md)

## Collaborators

1. **Jayashree Johnson** - [https://github.com/jayashreejohnson](https://github.com/jayashreejohnson)
2. **Kamal Domandula** - [https://github.com/kamaldomandula](https://github.com/kamaldomandula)
3. **Kethan Dosapati** - [https://github.com/dkethan](https://github.com/dkethan)

`arxiv-trend-predictor` helps you:

- collect arXiv CS paper data,
- analyze trends and domain movement,
- train an AI advisor model,
- and serve predictions via API for web/mobile apps.

## Main components

- `research_pipeline/` - scrape, analyze, train
- `backend/` - FastAPI endpoints
- `web_app/` - browser app
- `mobile_app/` - Flutter app

## Quick run

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
cp .env.example .env
python -m backend.main
```

## Want full details and project flow?

Use [README_FULL_FLOW.md](README_FULL_FLOW.md) for full implementation and updated pipeline steps.

## License

MIT License [LICENSE](LICENSE).
