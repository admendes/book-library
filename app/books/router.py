from uuid import UUID

from fastapi import APIRouter, Depends, Path, Query, status
from fastapi.responses import Response
from loguru import logger
from sqlalchemy.orm import Session

from app.auth.service import get_current_user
from app.books import crud
from app.books.schemas import (
    BookCreate,
    BookResponse,
    BookStats,
    BookUpdate,
    PaginatedResponse,
)
from app.core.database import get_db
from app.core.db_models import UserDB
from app.core.exceptions import BookNotFoundError

router = APIRouter(prefix="/books", tags=["books"])


@router.get("/stats", response_model=BookStats)
def get_stats(
    db: Session = Depends(get_db),
    current_user: UserDB = Depends(get_current_user),
) -> BookStats:
    return crud.get_stats(db, current_user.id)


@router.get("", response_model=PaginatedResponse[BookResponse])
def list_books(
    genre: str | None = None,
    search: str | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: UserDB = Depends(get_current_user),
) -> PaginatedResponse[BookResponse]:
    books = crud.get_books(db, current_user.id, genre=genre, search=search)
    total = len(books)
    start = (page - 1) * page_size
    return PaginatedResponse(
        total=total,
        page=page,
        page_size=page_size,
        items=[
            BookResponse.model_validate(b) for b in books[start : start + page_size]
        ],
    )


@router.post("", response_model=BookResponse, status_code=status.HTTP_201_CREATED)
def create_book(
    data: BookCreate,
    db: Session = Depends(get_db),
    current_user: UserDB = Depends(get_current_user),
) -> BookResponse:
    book = crud.add_book(db, data, current_user)
    logger.info(f'Book created: id={book.id} title="{book.title}"')
    return BookResponse.model_validate(book)


@router.get("/{book_id}", response_model=BookResponse)
def get_book(
    book_id: UUID = Path(..., description="The book's UUID"),
    db: Session = Depends(get_db),
    current_user: UserDB = Depends(get_current_user),
) -> BookResponse:
    book = crud.get_book(db, book_id, current_user.id)
    if book is None:
        raise BookNotFoundError(book_id)
    return BookResponse.model_validate(book)


@router.patch("/{book_id}", response_model=BookResponse)
def update_book(
    data: BookUpdate,
    book_id: UUID = Path(..., description="The book's UUID"),
    db: Session = Depends(get_db),
    current_user: UserDB = Depends(get_current_user),
) -> BookResponse:
    book = crud.get_book(db, book_id, current_user.id)
    if book is None:
        raise BookNotFoundError(book_id)
    updates = data.model_dump(exclude_unset=True)
    book = crud.update_book(db, book, updates)
    logger.info(f"Book updated: id={book_id}")
    return BookResponse.model_validate(book)


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(
    book_id: UUID = Path(..., description="The book's UUID"),
    db: Session = Depends(get_db),
    current_user: UserDB = Depends(get_current_user),
) -> Response:
    book = crud.get_book(db, book_id, current_user.id)
    if book is None:
        raise BookNotFoundError(book_id)
    crud.delete_book(db, book)
    logger.info(f"Book deleted: id={book_id}")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
