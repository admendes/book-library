# Book Library API

A simple REST API for managing a book collection, built with FastAPI and uv.

## Prerequisites

- [`uv`](https://docs.astral.sh/uv/) installed

## Setup

```bash
uv sync
```

## Run

```bash
uv run uvicorn app.main:app --reload
```

The API will be available at `http://localhost:8000`. Interactive docs at `http://localhost:8000/docs`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/books` | List books (see query params below) |
| `POST` | `/books` | Add a new book |
| `GET` | `/books/stats` | Aggregate stats (total, avg rating, status breakdown) |
| `GET` | `/books/{id}` | Get a book by ID |
| `PATCH` | `/books/{id}` | Partially update a book |
| `DELETE` | `/books/{id}` | Delete a book |

### `GET /books` query parameters

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `genre` | string | — | Filter by genre (case-insensitive exact match) |
| `search` | string | — | Search title and author (case-insensitive) |
| `page` | int ≥ 1 | `1` | Page number |
| `page_size` | int 1–100 | `10` | Items per page |

Response is wrapped in a paginated envelope:

```json
{
  "total": 42,
  "page": 1,
  "page_size": 10,
  "items": [...]
}
```

### Book fields

| Field | Type | Notes |
|-------|------|-------|
| `title` | string | 1–200 chars |
| `author` | string | 1–100 chars |
| `year` | int | 1000–2100 |
| `genre` | string \| null | optional, max 50 chars |
| `rating` | float \| null | optional, 0.0–5.0 |
| `status` | string | `want_to_read` \| `reading` \| `read` (default: `want_to_read`) |

## Lint & Format

```bash
uv run ruff check .
uv run ruff format .
```
