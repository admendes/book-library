from datetime import UTC, datetime
from uuid import UUID, uuid4

from sqlalchemy import ForeignKey, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserDB(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    hashed_password: Mapped[str]
    books: Mapped[list["BookDB"]] = relationship(back_populates="owner")


class BookDB(Base):
    __tablename__ = "books"

    id: Mapped[UUID] = mapped_column(Uuid, primary_key=True, default=uuid4)
    title: Mapped[str] = mapped_column(String(200))
    author: Mapped[str] = mapped_column(String(100))
    year: Mapped[int]
    genre: Mapped[str | None] = mapped_column(String(50))
    rating: Mapped[float | None]
    status: Mapped[str] = mapped_column(String(20), default="want_to_read")
    created_at: Mapped[datetime] = mapped_column(default=lambda: datetime.now(UTC))
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    owner: Mapped["UserDB"] = relationship(back_populates="books")
