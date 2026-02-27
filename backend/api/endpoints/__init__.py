from fastapi import APIRouter

from . import advisor, health

router = APIRouter()
router.include_router(health.router)
router.include_router(advisor.router)
