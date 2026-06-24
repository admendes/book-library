from uuid import UUID

from fastapi import APIRouter, Path, status
from fastapi.responses import Response
from loguru import logger

from app.exceptions import BookNotFoundError
from app.models import Book, BookCreate, BookResponse
from app.store import store

router = APIRouter(prefix="/books", tags=["books"])


@router.get("", response_model=list[BookResponse])
def list_books(genre: str | None = None) -> list[Book]:
    books = store.get_all()
    if genre is not None:
        books = [b for b in books if b.genre and b.genre.lower() == genre.lower()]
    return books


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
        logger.warning(f"Book not found: id={book_id}")
        raise BookNotFoundError(book_id)
    return book


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(
    book_id: UUID = Path(..., description="The book's UUID"),
) -> Response:
    deleted = store.delete(book_id)
    if not deleted:
        logger.warning(f"Book not found: id={book_id}")
        raise BookNotFoundError(book_id)
    logger.info(f"Book deleted: id={book_id}")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
