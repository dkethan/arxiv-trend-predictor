from pathlib import Path
import sys

from loguru import logger

from backend.core.config import settings


def _configure_logger() -> None:
    """
    Configure the global Loguru logger based on settings.
    """
    log_file: Path = settings.log_file
    log_file.parent.mkdir(parents=True, exist_ok=True)

    # Reset default handlers
    logger.remove()

    # Console handler
    logger.add(
        sys.stderr,
        level=settings.log_level.upper(),
        backtrace=False,
        diagnose=False,
    )

    # File handler with rotation
    logger.add(
        log_file,
        level=settings.log_level.upper(),
        rotation="10 MB",
        retention="10 days",
        enqueue=True,
        backtrace=False,
        diagnose=False,
    )


_configure_logger()


def get_logger(name: str | None = None):
    """
    Get a module-scoped logger instance.

    Example:
        from backend.logger import get_logger
        logger = get_logger(__name__)
    """
    if name:
        return logger.bind(module=name)
    return logger

