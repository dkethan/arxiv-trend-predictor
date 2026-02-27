from typing import Any, Dict

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from backend.api.services.advisor_service import advise, get_stats

router = APIRouter(prefix="/api/v1/advisor", tags=["advisor"])


class IdeaRequest(BaseModel):
    title: str = Field(
        ...,
        min_length=1,
        description="Proposed paper title or idea summary (required)",
    )
    abstract: str = Field(
        ...,
        min_length=1,
        description="Abstract or longer description of the idea (required)",
    )


@router.get("/stats", summary="Get comprehensive model statistics")
def get_model_stats() -> Dict[str, Any]:
    """
    Get comprehensive model statistics including:
    - Model metadata and type
    - Performance metrics (accuracy, F1 scores, hamming loss, etc.)
    - Available tech domains (all 21 domains)
    - Temporal trends for all domains (growth slope and R²)

    No parameters required - returns full model information.
    """
    try:
        return get_stats()
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to load model stats: {str(exc)}",
        ) from exc


@router.post("/advise", summary="Get comprehensive advice for a research idea")
def advisor_advise(payload: IdeaRequest) -> Dict[str, Any]:
    """
    Comprehensive Idea Advisor that analyzes research ideas and returns:
    - Primary tech domain prediction
    - All predicted domains (multi-label classification)
    - Confidence scores for each predicted domain
    - Growth trends and momentum for predicted domains
    - Model performance metrics

    Requires both title and abstract (mandatory fields).
    Both fields must be non-empty strings.

    Example Request:
    {
      "title": "Novel approach to transfer learning in computer vision",
      "abstract": "We propose a new method for transfer learning..."
    }

    Example Response:
    {
      "primary_domain": "Computer Vision",
      "all_domains": ["Computer Vision", "Machine Learning"],
      "domain_confidence": {
        "Computer Vision": 0.87,
        "Machine Learning": 0.65
      },
      "growth_info": {
        "Computer Vision": {"slope": 1.89, "r2": 0.85},
        "Machine Learning": {"slope": 3.12, "r2": 0.92}
      },
      "model_info": {
        "subset_accuracy": 0.2853,
        "hamming_loss": 0.0559,
        "macro_f1": 0.5977,
        "micro_f1": 0.5809,
        "samples_f1": 0.6074,
        "cv_micro_f1_mean": 0.5813,
        "cv_micro_f1_std": 0.0021
      }
    }
    """
    try:
        return advise(payload.title, payload.abstract)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except FileNotFoundError as exc:
        raise HTTPException(
            status_code=500,
            detail="Model files not found. Please ensure model artifacts exist in backend/models/",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500, detail=f"Internal server error: {str(exc)}"
        ) from exc
