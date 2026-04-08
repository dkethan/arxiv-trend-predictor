from typing import Any, Dict, Tuple

from research_pipeline.advisor.idea_advisor import (
    advise_idea,
    load_model,
)
from backend.logger import get_logger
from backend.api.services.advisory_service import build_advisory_payload
from backend.api.services.similarity_service import get_similar_papers_with_note

logger = get_logger(__name__)


def get_stats() -> Dict[str, Any]:
    """
    Get comprehensive model statistics and metadata.
    Returns all model information including domains, metrics, and temporal trends.
    """
    try:
        # Load model to verify it exists (ignore thresholds)
        model, vectorizer, mlb, trends, meta, thresholds = load_model()

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
    _validate_idea_payload(title, abstract)
    return _build_extended_advice(title.strip(), abstract.strip())


def compare_ideas(
    idea_a_title: str, idea_a_abstract: str, idea_b_title: str, idea_b_abstract: str
) -> Dict[str, Any]:
    _validate_idea_payload(idea_a_title, idea_a_abstract)
    _validate_idea_payload(idea_b_title, idea_b_abstract)

    idea_a_result = _build_extended_advice(idea_a_title.strip(), idea_a_abstract.strip())
    idea_b_result = _build_extended_advice(idea_b_title.strip(), idea_b_abstract.strip())

    verdict = _build_comparison_verdict(idea_a_result, idea_b_result)
    return {
        "idea_a_result": idea_a_result,
        "idea_b_result": idea_b_result,
        "final_verdict": verdict,
    }


def _validate_idea_payload(title: str, abstract: str) -> None:
    if not title or not title.strip():
        raise ValueError("Title is required and cannot be empty")
    if not abstract or not abstract.strip():
        raise ValueError("Abstract is required and cannot be empty")


def _build_extended_advice(title: str, abstract: str) -> Dict[str, Any]:
    base = advise_idea(title, abstract)
    if "error" in base:
        raise ValueError(base["error"])

    primary_domain = base.get("primary_domain") or ""
    domain_conf = base.get("domain_confidence", {}) or {}
    growth_info = base.get("growth_info", {}) or {}
    all_domains = base.get("all_domains") or [primary_domain]
    advisory = build_advisory_payload(
        title=title,
        abstract=abstract,
        primary_domain=primary_domain,
        domain_confidence=domain_conf,
        growth_info=growth_info,
        all_domains=all_domains,
    )
    similar, similarity_note = get_similar_papers_with_note(f"{title} {abstract}")

    base["advisory"] = advisory
    base["similar_papers"] = similar
    if similarity_note:
        base["similarity_note"] = similarity_note
    # Convenience fields for web compare and backward-compatible incremental rollout.
    base["opportunity_score"] = advisory.get("opportunity_score")
    base["signal_type"] = advisory.get("signal_type")
    base["domain_growth_score"] = advisory.get("growth_score")
    return base


def _comparison_metrics(result: Dict[str, Any]) -> Tuple[float, float]:
    score = float(result.get("opportunity_score") or 0.0)
    growth = float(result.get("domain_growth_score") or 0.0)
    return score, growth


def _build_comparison_verdict(
    idea_a_result: Dict[str, Any], idea_b_result: Dict[str, Any]
) -> str:
    a_score, a_growth = _comparison_metrics(idea_a_result)
    b_score, b_growth = _comparison_metrics(idea_b_result)

    if b_score > a_score:
        return "Idea B shows higher potential right now."
    if a_score > b_score:
        return "Idea A shows higher potential right now."
    if b_growth > a_growth:
        return "Idea B edges ahead on growth momentum."
    if a_growth > b_growth:
        return "Idea A edges ahead on growth momentum."
    return "Both ideas look evenly matched at the moment."
