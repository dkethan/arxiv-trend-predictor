from typing import Any, Dict

from research_pipeline.advisor.idea_advisor import advise_idea, train_domain_classifier, load_domain_model
from backend.logger import get_logger

logger = get_logger(__name__)


def ensure_model_trained() -> Dict[str, Any]:
    """
    Ensure the domain model is trained.
    If model files are missing, trains a new model and returns metrics.
    If present, returns a simple status dict.
    """
    vectorizer, classifier = load_domain_model()
    if vectorizer is not None and classifier is not None:
        return {"trained": True, "just_trained": False}

    logger.info("Domain model not found; training a new model …")
    metrics = train_domain_classifier()
    return {
        "trained": True,
        "just_trained": True,
        "accuracy": metrics.get("accuracy"),
        "macro_f1": metrics.get("macro_f1"),
    }


def advise(title: str, abstract: str) -> Dict[str, Any]:
    """
    Invoke the Idea Advisor for a given title + abstract.
    Assumes the model has already been trained.
    """
    return advise_idea(title, abstract)

