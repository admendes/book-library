from datetime import UTC, datetime
from uuid import UUID, uuid4

from pydantic import BaseModel, Field


class Book(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    title: str
    author: str
    year: int
    genre: str | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class BookCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    author: str = Field(..., min_length=1, max_length=100)
    year: int = Field(..., ge=1000, le=2100)
    genre: str | None = Field(default=None, max_length=50)


class BookResponse(Book):
    pass
