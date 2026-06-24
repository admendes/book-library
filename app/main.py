from fastapi import FastAPI

from app.exceptions import register_exception_handlers
from app.logging import add_request_logging, setup_logging
from app.routes import router

setup_logging()

app = FastAPI(
    title="Book Library API",
    version="0.1.0",
    description="A simple book library API",
)

add_request_logging(app)
register_exception_handlers(app)
app.include_router(router)
