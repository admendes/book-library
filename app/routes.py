from uuid import UUID

from fastapi import APIRouter, Path, Query, status
from fastapi.responses import Response
from loguru import logger

from app.exceptions import BookNotFoundError
from app.models import (
    Book,
    BookCreate,
    BookResponse,
    BookStats,
    BookUpdate,
    PaginatedResponse,
)
from app.store import store

router = APIRouter(prefix="/books", tags=["books"])


@router.get("/stats", response_model=BookStats)
def get_stats() -> BookStats:
    books = store.get_all()
    ratings = [b.rating for b in books if b.rating is not None]
    return BookStats(
        total=len(books),
        average_rating=sum(ratings) / len(ratings) if ratings else None,
        status_breakdown={
            "want_to_read": sum(1 for b in books if b.status == "want_to_read"),
            "reading": sum(1 for b in books if b.status == "reading"),
            "read": sum(1 for b in books if b.status == "read"),
        },
    )


@router.get("", response_model=PaginatedResponse[BookResponse])
def list_books(
    genre: str | None = None,
    search: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
) -> PaginatedResponse[Book]:
    books = store.get_all()
    if genre is not None:
        books = [b for b in books if b.genre and b.genre.lower() == genre.lower()]
    if search is not None:
        term = search.lower()
        books = [
            b for b in books if term in b.title.lower() or term in b.author.lower()
        ]
    total = len(books)
    start = (page - 1) * page_size
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=books[start : start + page_size],
    )


@router.post("", response_model=BookResponse, status_code=status.HTTP_201_CREATED)
def create_book(data: BookCreate) -> Book:
    book = Book(**data.model_dump())
    store.add(book)
    logger.info(f'Book created: id={book.id} title="{book.title}"')
    return book


@router.get("/{book_id}", response_model=BookResponse)
def get_book(
    book_id: UUID = Path(..., description="The book's UUID"),
) -> Book:
    book = store.get_by_id(book_id)
    if book is None:
        raise BookNotFoundError(book_id)
    return book


@router.patch("/{book_id}", response_model=BookResponse)
def update_book(
    data: BookUpdate,
    book_id: UUID = Path(..., description="The book's UUID"),
) -> Book:
    updates = data.model_dump(exclude_unset=True)
    book = store.update(book_id, updates)
    if book is None:
        raise BookNotFoundError(book_id)
    logger.info(f"Book updated: id={book_id}")
    return book


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(
    book_id: UUID = Path(..., description="The book's UUID"),
) -> Response:
    deleted = store.delete(book_id)
    if not deleted:
        raise BookNotFoundError(book_id)
    logger.info(f"Book deleted: id={book_id}")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
