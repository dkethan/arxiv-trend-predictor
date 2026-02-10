from typing import Any, Dict

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from backend.api.services.advisor_service import advise, ensure_model_trained

router = APIRouter(prefix="/api/v1/advisor", tags=["advisor"])


class IdeaRequest(BaseModel):
    title: str = Field(..., description="Proposed paper title or idea summary")
    abstract: str = Field(
        "",
        description="Optional abstract or longer description of the idea",
    )


class TrainStatus(BaseModel):
    trained: bool
    just_trained: bool
    accuracy: float | None = None
    macro_f1: float | None = None


@router.post("/train", response_model=TrainStatus, summary="Train domain classifier")
def train_model() -> TrainStatus:
    """
    Train (or re-train) the domain classifier on the collected arXiv data.
    """
    metrics = ensure_model_trained()
    return TrainStatus(**metrics)


@router.get("/status", response_model=TrainStatus, summary="Advisor model status")
def advisor_status() -> TrainStatus:
    """
    Check whether the advisor model is trained.
    Does not train the model; only inspects the presence of model files.
    """
    from research_pipeline.advisor.idea_advisor import load_domain_model

    vectorizer, classifier = load_domain_model()
    trained = vectorizer is not None and classifier is not None
    return TrainStatus(trained=trained, just_trained=False, accuracy=None, macro_f1=None)


@router.post("/advise", summary="Get advice for a research idea")
def advisor_advise(payload: IdeaRequest) -> Dict[str, Any]:
    """
    Invoke the Idea Advisor:
    - Predicts best-fit tech domain
    - Scores how 'trending' the domain is in the dataset
    - Suggests useful keywords to emphasize
    """
    try:
        return advise(payload.title, payload.abstract)
    except RuntimeError as exc:
        # Likely cause: model not trained yet
        raise HTTPException(status_code=400, detail=str(exc)) from exc

