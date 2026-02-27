from fastapi import APIRouter

from backend.api.services.health_service import check_liveness, check_readiness

router = APIRouter(tags=["health"])


@router.get("/health", summary="Basic health check")
def health() -> dict:
    """Simple OK response to indicate the service is up."""
    return {"status": "ok"}


@router.get("/health/live", summary="Liveness probe")
def live() -> dict:
    """Liveness probe."""
    return check_liveness()


@router.get("/health/ready", summary="Readiness probe")
def ready() -> dict:
    """
    Readiness probe focused on the Idea Advisor model and its dependencies.
    """
    return check_readiness()

