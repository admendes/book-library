from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


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


class BookResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    author: str
    year: int
    genre: str | None
    rating: float | None
    status: Literal["want_to_read", "reading", "read"]
    created_at: datetime


class PaginatedResponse[T](BaseModel):
    total: int
    page: int
    page_size: int
    items: list[T]


class BookStats(BaseModel):
    total: int
    average_rating: float | None
    status_breakdown: dict[str, int]
