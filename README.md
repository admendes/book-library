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
| `GET` | `/books` | List all books (optional `?genre=` filter) |
| `POST` | `/books` | Add a new book |
| `GET` | `/books/{id}` | Get a book by ID |
| `DELETE` | `/books/{id}` | Delete a book |

## Lint & Format

```bash
uv run ruff check .
uv run ruff format .
```
