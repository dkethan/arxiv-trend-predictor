"""
Logging utilities for arxiv-trend-predictor.

Typical usage:

    from backend.logger import get_logger
    logger = get_logger(__name__)
    logger.info("Message")
"""

from .app_logger import get_logger  # noqa: F401

