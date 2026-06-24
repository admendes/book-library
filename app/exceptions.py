from uuid import UUID

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from loguru import logger
from pydantic import BaseModel


class BookNotFoundError(Exception):
    def __init__(self, book_id: UUID) -> None:
        self.book_id = book_id
        super().__init__(f"Book {book_id} not found")


class ErrorResponse(BaseModel):
    error: str
    detail: str


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(BookNotFoundError)
    async def book_not_found_handler(
        request: Request, exc: BookNotFoundError
    ) -> JSONResponse:
        detail = f"Book {exc.book_id} not found"
        logger.bind(
            method=request.method,
            path=request.url.path,
            status_code=404,
            detail=detail,
        ).warning("Request error")
        return JSONResponse(
            status_code=404,
            content={"error": "not_found", "detail": detail},
        )

    @app.exception_handler(RequestValidationError)
    async def validation_error_handler(
        request: Request, exc: RequestValidationError
    ) -> JSONResponse:
        detail = "; ".join(e["msg"] for e in exc.errors())
        logger.bind(
            method=request.method,
            path=request.url.path,
            status_code=422,
            detail=detail,
        ).warning("Request error")
        return JSONResponse(
            status_code=422,
            content={"error": "validation_error", "detail": detail},
        )

    @app.exception_handler(Exception)
    async def generic_error_handler(request: Request, exc: Exception) -> JSONResponse:
        detail = "An unexpected error occurred"
        logger.bind(
            method=request.method,
            path=request.url.path,
            status_code=500,
            detail=detail,
        ).error("Unhandled exception")
        return JSONResponse(
            status_code=500,
            content={"error": "internal_error", "detail": detail},
        )
