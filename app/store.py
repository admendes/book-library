from uuid import UUID

from app.models import Book


class BookStore:
    def __init__(self) -> None:
        self._books: dict[UUID, Book] = {}

    def add(self, book: Book) -> Book:
        self._books[book.id] = book
        return book

    def get_all(self) -> list[Book]:
        return list(self._books.values())

    def get_by_id(self, book_id: UUID) -> Book | None:
        return self._books.get(book_id)

    def delete(self, book_id: UUID) -> bool:
        if book_id in self._books:
            del self._books[book_id]
            return True
        return False


store = BookStore()
