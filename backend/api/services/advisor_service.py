from typing import Any, Dict

from research_pipeline.advisor.idea_advisor import (
    advise_idea,
    load_model,
    get_all_domains,
    get_all_trends,
    get_model_info,
)
from backend.logger import get_logger

logger = get_logger(__name__)


def get_stats() -> Dict[str, Any]:
    """
    Get comprehensive model statistics and metadata.
    Returns all model information including domains, metrics, and temporal trends.
    """
    try:
        # Load model to verify it exists
        model, vectorizer, mlb, trends, meta = load_model()

        # Return comprehensive stats
        return {
            "model_loaded": True,
            "model_type": meta.get("model"),
            "classification_type": meta.get("classification_type"),
            "n_classes": meta.get("n_classes"),
            "available_domains": meta.get("classes", []),
            "metrics": meta.get("metrics", {}),
            "temporal_trends": trends,
        }
    except Exception as e:
        logger.error("Failed to load model stats: {}", str(e))
        raise


def advise(title: str, abstract: str) -> Dict[str, Any]:
    """
    Invoke the Idea Advisor with comprehensive output.
    Requires both title and abstract to be non-empty.

    Returns:
        - primary_domain: Main predicted tech domain
        - all_domains: All predicted domains (multi-label)
        - domain_confidence: Confidence scores for each domain
        - growth_info: Temporal trends for predicted domains
        - model_info: Model performance metrics
    """
    if not title or not title.strip():
        raise ValueError("Title is required and cannot be empty")
    if not abstract or not abstract.strip():
        raise ValueError("Abstract is required and cannot be empty")

    return advise_idea(title, abstract)
