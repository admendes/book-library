from fastapi import FastAPI

from app.auth.router import router as auth_router
from app.books.router import router as books_router
from app.core.database import Base, engine
from app.core.exceptions import register_exception_handlers
from app.core.logging import add_request_logging, setup_logging

setup_logging()

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Book Library API",
    version="0.1.0",
    description="A simple book library API",
)

add_request_logging(app)
register_exception_handlers(app)
app.include_router(auth_router)
app.include_router(books_router)
