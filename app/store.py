from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db_models import BookDB, UserDB
from app.models import BookCreate, BookStats


def add_book(db: Session, data: BookCreate, owner: UserDB) -> BookDB:
    book = BookDB(**data.model_dump(), owner_id=owner.id)
    db.add(book)
    db.commit()
    db.refresh(book)
    return book


def get_books(
    db: Session,
    owner_id: int,
    genre: str | None = None,
    search: str | None = None,
) -> list[BookDB]:
    q = db.query(BookDB).filter(BookDB.owner_id == owner_id)
    if genre is not None:
        q = q.filter(func.lower(BookDB.genre) == genre.lower())
    if search is not None:
        term = f"%{search.lower()}%"
        q = q.filter(
            func.lower(BookDB.title).like(term) | func.lower(BookDB.author).like(term)
        )
    return q.all()


def get_book(db: Session, book_id: UUID, owner_id: int) -> BookDB | None:
    return (
        db.query(BookDB)
        .filter(BookDB.id == book_id, BookDB.owner_id == owner_id)
        .first()
    )


def update_book(db: Session, book: BookDB, updates: dict[str, object]) -> BookDB:
    for key, value in updates.items():
        setattr(book, key, value)
    db.commit()
    db.refresh(book)
    return book


def delete_book(db: Session, book: BookDB) -> None:
    db.delete(book)
    db.commit()


def get_stats(db: Session, owner_id: int) -> BookStats:
    books = get_books(db, owner_id)
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
