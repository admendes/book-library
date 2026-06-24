import sys
import time
from collections.abc import Awaitable, Callable

from fastapi import FastAPI
from loguru import logger
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


def setup_logging() -> None:
    logger.remove()
    logger.add(
        sys.stdout,
        format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {message}",
        level="INFO",
        colorize=True,
    )


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        start = time.perf_counter()
        response = await call_next(request)
        elapsed_ms = (time.perf_counter() - start) * 1000
        method = request.method
        path = request.url.path
        status = response.status_code
        logger.info(f"{method} {path} → {status} [{elapsed_ms:.0f}ms]")
        return response


def add_request_logging(app: FastAPI) -> None:
    app.add_middleware(RequestLoggingMiddleware)
