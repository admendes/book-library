from datetime import UTC, datetime
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class Book(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    title: str
    author: str
    year: int
    genre: str | None = None
    rating: float | None = Field(default=None, ge=0.0, le=5.0)
    status: Literal["want_to_read", "reading", "read"] = "want_to_read"
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class BookCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    author: str = Field(..., min_length=1, max_length=100)
    year: int = Field(..., ge=1000, le=2100)
    genre: str | None = Field(default=None, max_length=50)
    rating: float | None = Field(default=None, ge=0.0, le=5.0)
    status: Literal["want_to_read", "reading", "read"] = "want_to_read"


class BookUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    author: str | None = Field(default=None, min_length=1, max_length=100)
    year: int | None = Field(default=None, ge=1000, le=2100)
    genre: str | None = Field(default=None, max_length=50)
    rating: float | None = Field(default=None, ge=0.0, le=5.0)
    status: Literal["want_to_read", "reading", "read"] | None = None


class BookResponse(Book):
    pass


class PaginatedResponse[T](BaseModel):
    total: int
    page: int
    page_size: int
    items: list[T]


class BookStats(BaseModel):
    total: int
    average_rating: float | None
    status_breakdown: dict[str, int]
