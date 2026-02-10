from fastapi import APIRouter

from backend.api.endpoints.app_ import health, advisor

router = APIRouter()
router.include_router(health.router)
router.include_router(advisor.router)

