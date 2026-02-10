from pathlib import Path

from backend.core.config import settings
from backend.logger import get_logger

logger = get_logger(__name__)


def check_liveness() -> dict:
    """Simple liveness check."""
    return {"status": "ok"}


def check_readiness() -> dict:
    """
    Readiness check focused on the Idea Advisor:
    - Domain model files present
    - Analysis results present (optional but recommended)
    """
    model_dir = settings.model_dir
    analysis_dir = settings.analysis_output_dir

    classifier_path = model_dir / "domain_classifier.pkl"
    vectorizer_path = model_dir / "domain_vectorizer.pkl"
    analysis_path = analysis_dir / "analysis_results.json"

    ready_model = classifier_path.exists() and vectorizer_path.exists()
    ready_analysis = analysis_path.exists()

    status = {
        "model_dir": str(model_dir),
        "analysis_dir": str(analysis_dir),
        "has_domain_classifier": classifier_path.exists(),
        "has_domain_vectorizer": vectorizer_path.exists(),
        "has_analysis_results": analysis_path.exists(),
        "ready": ready_model and ready_analysis,
    }

    if not status["ready"]:
        logger.warning("Readiness check failed: {}", status)

    return status

