import os
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Settings:
    """
    Central application settings.

    Values are loaded from environment variables with sensible defaults so
    the app works out-of-the-box for local development.
    """

    # Project root (one level above `backend/`)
    project_root: Path = Path(__file__).resolve().parents[2]

    # Paths
    data_dir: Path = Path(os.getenv("DATA_DIR", project_root / "data"))
    model_dir: Path = Path(os.getenv("MODEL_DIR", project_root / "backend" / "models"))
    log_level: str = os.getenv("LOG_LEVEL", "INFO")

    # ArXiv scraper configuration
    arxiv_start_year: int = int(os.getenv("ARXIV_START_YEAR", "2000"))
    arxiv_end_year: int = int(os.getenv("ARXIV_END_YEAR", "2025"))
    papers_per_category_per_year: int = int(
        os.getenv("PAPERS_PER_CATEGORY_PER_YEAR", "100")
    )

    # Feature flags
    enable_analysis_embeddings: bool = os.getenv(
        "ENABLE_ANALYSIS_EMBEDDINGS", "true"
    ).lower() in {"1", "true", "yes", "on"}
    enable_plotting: bool = os.getenv("ENABLE_PLOTTING", "true").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }

    # API settings (used by uvicorn/FastAPI entrypoints)
    # Render and similar platforms set PORT; fall back to API_PORT then 60000
    api_host: str = os.getenv("API_HOST", "0.0.0.0")
    api_port: int = int(os.getenv("PORT") or os.getenv("API_PORT", "60000"))
    similarity_top_k: int = int(os.getenv("SIMILARITY_TOP_K", "5"))
    pinecone_api_key: str = os.getenv("PINECONE_API_KEY", "")
    pinecone_index_host: str = os.getenv("PINECONE_INDEX_HOST", "")
    pinecone_index_namespace: str = os.getenv("PINECONE_NAMESPACE", "__default__")
    pinecone_text_field: str = os.getenv("PINECONE_TEXT_FIELD", "text")
    pinecone_api_version: str = os.getenv("PINECONE_API_VERSION", "2025-01")
    pinecone_timeout_seconds: float = float(
        os.getenv("PINECONE_TIMEOUT_SECONDS", "5.0")
    )

    @property
    def arxiv_data_dir(self) -> Path:
        return Path(self.data_dir) / "arxiv_data"

    @property
    def analysis_output_dir(self) -> Path:
        return Path(self.data_dir) / "analysis_output"

    @property
    def log_file(self) -> Path:
        return Path(os.getenv("LOG_FILE", self.project_root / "logs" / "app.log"))



# Singleton settings instance used throughout the project
settings = Settings()

