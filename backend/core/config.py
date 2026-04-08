import os
from pathlib import Path


class Settings:
    def __init__(self):
        self.project_root: Path = Path(__file__).resolve().parents[2]

        self.data_dir: Path = Path(os.getenv("DATA_DIR", str(self.project_root / "data")))
        self.model_dir: Path = Path(os.getenv("MODEL_DIR", str(self.project_root / "backend" / "models")))
        self.log_level: str = os.getenv("LOG_LEVEL", "INFO")

        self.arxiv_start_year: int = int(os.getenv("ARXIV_START_YEAR", "2000"))
        self.arxiv_end_year: int = int(os.getenv("ARXIV_END_YEAR", "2025"))
        self.papers_per_category_per_year: int = int(os.getenv("PAPERS_PER_CATEGORY_PER_YEAR", "100"))

        self.enable_analysis_embeddings: bool = os.getenv("ENABLE_ANALYSIS_EMBEDDINGS", "true").lower() in {"1", "true", "yes", "on"}
        self.enable_plotting: bool = os.getenv("ENABLE_PLOTTING", "true").lower() in {"1", "true", "yes", "on"}

        self.api_host: str = os.getenv("API_HOST", "0.0.0.0")
        self.api_port: int = int(os.getenv("PORT") or os.getenv("API_PORT", "60000"))
        self.similarity_top_k: int = int(os.getenv("SIMILARITY_TOP_K", "5"))

        self.pinecone_api_key: str = os.getenv("PINECONE_API_KEY", "")
        self.pinecone_index_host: str = os.getenv("PINECONE_INDEX_HOST", "")
        self.pinecone_index_namespace: str = os.getenv("PINECONE_NAMESPACE", "__default__")
        self.pinecone_text_field: str = os.getenv("PINECONE_TEXT_FIELD", "text")
        self.pinecone_api_version: str = os.getenv("PINECONE_API_VERSION", "2025-01")
        self.pinecone_timeout_seconds: float = float(os.getenv("PINECONE_TIMEOUT_SECONDS", "5.0"))

    @property
    def arxiv_data_dir(self) -> Path:
        return Path(self.data_dir) / "arxiv_data"

    @property
    def analysis_output_dir(self) -> Path:
        return Path(self.data_dir) / "analysis_output"

    @property
    def log_file(self) -> Path:
        return Path(os.getenv("LOG_FILE", str(self.project_root / "logs" / "app.log")))


# Singleton settings instance used throughout the project
settings = Settings()
