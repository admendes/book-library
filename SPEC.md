# Book Library API — Project Spec

## Overview

A simple book library REST API built with Python, FastAPI, and uv. The app allows users to manage a collection of books — adding, listing, fetching, and deleting them. Data is stored in memory (no database required). Focus is on clean structure, type safety, logging, and proper error handling.

---

## Tech Stack

| Tool | Purpose |
|---|---|
| `uv` | Project manager (replaces pip + venv) |
| `ruff` | Linter and formatter |
| `fastapi` | Web framework |
| `uvicorn` | ASGI server |
| `pydantic` | Data validation and type checking (comes with FastAPI) |
| `loguru` | Structured API request/response logging |

---

## Project Structure

```
book-library/
├── pyproject.toml
├── .python-version
├── uv.lock
├── README.md
└── app/
    ├── __init__.py
    ├── main.py          ← FastAPI app entry point, middleware
    ├── models.py        ← Pydantic models (Book, request/response schemas)
    ├── store.py         ← In-memory data store
    ├── routes.py        ← All API endpoints
    ├── exceptions.py    ← Custom exceptions and exception handlers
    └── logging.py       ← Loguru setup and request logging middleware
```

---

## Setup Instructions

### 1. Initialise the project

```bash
uv init book-library
cd book-library
uv python install 3.12
```

### 2. Add dependencies

```bash
uv add fastapi uvicorn loguru
uv add --dev ruff
```

### 3. `pyproject.toml` config

Ensure the following sections exist in `pyproject.toml`:

```toml
[project]
name = "book-library"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = [
    "fastapi",
    "uvicorn",
    "loguru",
]

[project.scripts]
start = "uvicorn app.main:app --reload"

[dependency-groups]
dev = ["ruff"]

[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = ["E", "F", "I", "UP"]
fix = true

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

### 4. Run the app

```bash
uv run uvicorn app.main:app --reload
```

---

## Data Models (`app/models.py`)

### `Book`

The core domain model stored internally.

```python
from pydantic import BaseModel, Field
from uuid import UUID, uuid4
from datetime import datetime

class Book(BaseModel):
    id: UUID = Field(default_factory=uuid4)
    title: str
    author: str
    year: int
    genre: str | None = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

### `BookCreate`

Input schema for creating a book (no `id` or `created_at`).

```python
class BookCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    author: str = Field(..., min_length=1, max_length=100)
    year: int = Field(..., ge=1000, le=2100)
    genre: str | None = Field(default=None, max_length=50)
```

### `BookResponse`

Output schema (same as `Book`, used for explicit response typing).

---

## In-Memory Store (`app/store.py`)

A simple class that holds a `dict[UUID, Book]` and exposes typed methods.

```python
class BookStore:
    def __init__(self) -> None:
        self._books: dict[UUID, Book] = {}

    def add(self, book: Book) -> Book: ...
    def get_all(self) -> list[Book]: ...
    def get_by_id(self, book_id: UUID) -> Book | None: ...
    def delete(self, book_id: UUID) -> bool: ...
```

Instantiate a single global `store = BookStore()` at the bottom of this file. Import `store` in `routes.py`.

---

## API Endpoints (`app/routes.py`)

All routes are on an `APIRouter` with prefix `/books` and tag `books`.

| Method | Path | Description | Request Body | Response |
|---|---|---|---|---|
| `GET` | `/books` | List all books | — | `list[BookResponse]` |
| `POST` | `/books` | Add a new book | `BookCreate` | `BookResponse` (201) |
| `GET` | `/books/{book_id}` | Get a single book | — | `BookResponse` |
| `DELETE` | `/books/{book_id}` | Delete a book | — | `204 No Content` |

### Endpoint details

**`GET /books`**
- Returns all books as a list. Returns `[]` if empty.
- Optional query param: `?genre=fiction` to filter by genre (case-insensitive).

**`POST /books`**
- Validates input with `BookCreate`.
- Creates a `Book` (with auto `id` and `created_at`), saves to store, returns it with status `201`.

**`GET /books/{book_id}`**
- Parses `book_id` as `UUID`. Raises `BookNotFoundError` if missing.

**`DELETE /books/{book_id}`**
- Parses `book_id` as `UUID`. Raises `BookNotFoundError` if missing.
- Returns `204 No Content` on success (no body).

---

## Exception Handling (`app/exceptions.py`)

### Custom exceptions

```python
class BookNotFoundError(Exception):
    def __init__(self, book_id: UUID) -> None:
        self.book_id = book_id
        super().__init__(f"Book {book_id} not found")
```

### Error response schema

```python
class ErrorResponse(BaseModel):
    error: str
    detail: str
```

### Exception handlers

Register handlers on the FastAPI app in `main.py`:

- `BookNotFoundError` → `404` with `{"error": "not_found", "detail": "Book <id> not found"}`
- `RequestValidationError` (FastAPI built-in) → `422` with `{"error": "validation_error", "detail": "<pydantic message>"}`
- `Exception` (catch-all) → `500` with `{"error": "internal_error", "detail": "An unexpected error occurred"}`

---

## Logging (`app/logging.py`)

Use `loguru` for all logging. No `print()` statements anywhere.

### Setup

Configure loguru in a `setup_logging()` function called once at startup:

```python
from loguru import logger
import sys

def setup_logging() -> None:
    logger.remove()
    logger.add(
        sys.stdout,
        format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {message}",
        level="INFO",
        colorize=True,
    )
```

### Request logging middleware

Add a Starlette middleware in `main.py` (or `logging.py`) that logs every request:

```
INFO | GET /books → 200 [45ms]
INFO | POST /books → 201 [12ms]
INFO | GET /books/bad-uuid → 404 [3ms]
```

Log format: `{method} {path} → {status_code} [{elapsed_ms}ms]`

Use `time.perf_counter()` to measure elapsed time.

### Logging in routes

- `POST /books`: log `Book created: id={book.id} title="{book.title}"`
- `DELETE /books/{id}`: log `Book deleted: id={book_id}`
- On `BookNotFoundError`: log `Book not found: id={book_id}` at WARNING level

---

## App Entry Point (`app/main.py`)

```python
from fastapi import FastAPI
from app.routes import router
from app.exceptions import register_exception_handlers
from app.logging import setup_logging, add_request_logging

setup_logging()

app = FastAPI(
    title="Book Library API",
    version="0.1.0",
    description="A simple book library API",
)

add_request_logging(app)
register_exception_handlers(app)
app.include_router(router)
```

---

## Type Safety Rules

- All functions must have full type annotations (parameters + return types).
- No use of `Any` from `typing` unless absolutely unavoidable.
- Pydantic models are used for all input/output at the boundary.
- UUIDs are always typed as `UUID`, never as raw `str`.
- `book_id` path parameters should use FastAPI's `Path(...)` with a description.

---

## Ruff & Code Style Rules

- Run `uv run ruff check . --fix` and `uv run ruff format .` before considering any file done.
- Imports must be sorted (`I` rule — isort style).
- No unused imports.
- Use f-strings (not `.format()` or `%`).
- Prefer `X | Y` union syntax over `Optional[X]` (`UP` rule).

---

## README.md

The generated README must include:

1. Project description (one sentence)
2. Prerequisites (`uv` installed)
3. Setup steps (`uv sync`)
4. How to run (`uv run uvicorn app.main:app --reload`)
5. Endpoint table (method, path, description)
6. How to lint/format (`uv run ruff check .`, `uv run ruff format .`)

---

## Acceptance Criteria

The implementation is complete when:

- [ ] `uv run uvicorn app.main:app --reload` starts the server with no errors
- [ ] `GET /books` returns `[]` on a fresh start
- [ ] `POST /books` with valid JSON creates and returns a book with `id` and `created_at`
- [ ] `POST /books` with invalid data returns `422` with an `error` + `detail` body
- [ ] `GET /books/{id}` returns the book if it exists
- [ ] `GET /books/{id}` returns `404` with proper error body if it doesn't
- [ ] `DELETE /books/{id}` returns `204` and the book is gone
- [ ] `GET /books?genre=fiction` filters results (case-insensitive)
- [ ] Every request is logged to stdout with method, path, status, and duration
- [ ] `uv run ruff check .` exits with code `0` (no lint errors)
- [ ] `uv run ruff format . --check` exits with code `0` (no formatting issues)
- [ ] All functions have type annotations
