# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
uv run uvicorn app.main:app --reload   # start dev server (http://localhost:8000)
uv run ruff check . --fix              # lint with autofix
uv run ruff format .                   # format
bash test.sh                           # full curl-based test suite (server must be running)
uv sync                                # install/sync dependencies
uv add <package>                       # add a dependency
```

Interactive API docs are available at `http://localhost:8000/docs` when the server is running.

`library.db` is the SQLite database file, created automatically on first run. It is not committed to git.

`test.sh` registers users with timestamped usernames (e.g. `alice_1234567890`) so re-runs don't collide on the persistent database.

## Project structure

```
book-library/
├── app/
│   ├── main.py              # FastAPI app entry point
│   ├── core/
│   │   ├── database.py      # SQLAlchemy engine, session, Base, get_db
│   │   ├── db_models.py     # ORM models (UserDB, BookDB)
│   │   ├── exceptions.py    # Custom exceptions and error handlers
│   │   └── logging.py       # Loguru setup and request middleware
│   ├── auth/
│   │   ├── schemas.py       # UserCreate, UserResponse, Token
│   │   ├── service.py       # JWT creation, get_current_user dependency
│   │   └── router.py        # POST /auth/register, /auth/login
│   └── books/
│       ├── schemas.py       # BookCreate, BookUpdate, BookResponse, PaginatedResponse, BookStats
│       ├── crud.py          # Database query functions
│       └── router.py        # Book endpoints
├── pyproject.toml           # Dependencies and ruff config
├── test.sh                  # curl-based test suite
├── library.db               # SQLite database (auto-created, not in git)
└── uv.lock
```

## Architecture

The app is a FastAPI REST API backed by SQLite via SQLAlchemy, organised into feature modules.

**Layer responsibilities:**

- `app/main.py` — creates the FastAPI app, calls `Base.metadata.create_all` on startup, registers middleware and exception handlers, mounts both routers
- `app/core/database.py` — SQLAlchemy engine, `SessionLocal`, `Base`, and `get_db` (a FastAPI dependency that opens/closes a session per request)
- `app/core/db_models.py` — SQLAlchemy ORM tables: `UserDB` (users) and `BookDB` (books). Books have a FK to their owner; queries always filter by `owner_id`
- `app/core/exceptions.py` — `BookNotFoundError` custom exception + handlers for 404, `HTTPException` (401/403/409), 422, and 500; all return `{"error": "...", "detail": "..."}`
- `app/core/logging.py` — loguru setup and `RequestLoggingMiddleware` (logs method, path, status, duration per request)
- `app/auth/schemas.py` — Pydantic schemas: `UserCreate`, `UserResponse` (with `from_attributes=True`), `Token`
- `app/auth/service.py` — JWT creation (`create_access_token`) and the `get_current_user` FastAPI dependency (validates Bearer token, returns `UserDB`)
- `app/auth/router.py` — `POST /auth/register` and `POST /auth/login` (bcrypt password hashing/verification)
- `app/books/schemas.py` — `BookCreate`, `BookUpdate`, `BookResponse` (with `from_attributes=True`), `PaginatedResponse[T]`, `BookStats`
- `app/books/crud.py` — all database query logic as plain functions (`add_book`, `get_books`, `get_book`, `update_book`, `delete_book`, `get_stats`). Routes call these; they never touch SQL directly
- `app/books/router.py` — all six book endpoints; every route depends on `get_current_user`, so unauthenticated requests are rejected before any book logic runs

**Request flow:** request → `RequestLoggingMiddleware` → route → `get_db` (opens session) + `get_current_user` (validates JWT, fetches user; shares the same session via FastAPI dependency caching) → `crud.*` function → response

**Auth:** JWT via PyJWT (HS256, 60-minute expiry). Clients send `Authorization: Bearer <token>`. The `SECRET_KEY` in `app/auth/service.py` is hardcoded for development — replace it with `os.environ["SECRET_KEY"]` before deploying.

**User isolation:** `BookDB.owner_id` is a FK to `UserDB.id`. Every query in `app/books/crud.py` filters on `owner_id`, so users can only access their own books.

**ORM → Pydantic:** Routes call `BookResponse.model_validate(book_db_instance)` explicitly to convert ORM objects to response schemas (`from_attributes=True` enables this).

## Adding a new endpoint

1. Add request/response schemas to `app/books/schemas.py`
2. Add the query logic to `app/books/crud.py`
3. Add the route to `app/books/router.py` with `Depends(get_current_user)` and `Depends(get_db)`

**Route ordering caveat:** fixed-path routes (e.g. `/books/stats`) must be defined before parameterised routes (e.g. `/books/{book_id}`) in `router.py`, otherwise FastAPI matches the fixed segment as a UUID and returns a 422.

## Code style

- ruff rules: `E`, `F`, `I` (isort), `UP` (pyupgrade) — targeting Python 3.12
- All functions must have full type annotations; no `Any`
- Use `str | None` union syntax, not `Optional[str]`
- Use PEP 695 generic syntax (`class Foo[T](BaseModel)`) not `Generic[T]`
- All logging via loguru — no `print()`; structured error logging uses `logger.bind(method=, path=, status_code=, detail=)`
- Always run `uv run ruff check . --fix && uv run ruff format .` before considering a file done

## Environment

- `SECRET_KEY` — JWT signing key (hardcoded in dev, use env var in prod)
- Python 3.12 required

## Testing

- Server must be running before `bash test.sh`
- Usernames are timestamped to avoid collisions on re-runs
- To test a single endpoint manually, check the curl examples at the bottom of `test.sh`

## Common mistakes

- Never import from `app.core.db_models` in schemas — ORM models and Pydantic schemas are separate
- Never skip `Depends(get_current_user)` on book routes
- Never define a parameterised route before a fixed-path route (e.g. `/stats` must come before `/{book_id}`)
- Never hardcode a new `SessionLocal()` — always use the `get_db` dependency
- Never use `Optional[X]` — use `X | None`
- Never use `Generic[T]` — use PEP 695 syntax

## Do not touch

- `library.db` — never commit this, never delete it during a task
- `uv.lock` — never edit manually
- The `get_db` + `get_current_user` dependency sharing pattern — do not refactor this

## Before deploying

- Replace hardcoded `SECRET_KEY` with `os.environ["SECRET_KEY"]`
- Set `reload=False` in uvicorn