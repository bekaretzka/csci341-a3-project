"""
Research Conference and Paper Review Management System (CSCI 341, Assignment 3, Part 3).

Run from the project root:
    uvicorn app.main:app --reload

Then open http://127.0.0.1:8000/  (the web pages). The same operations are also
available as interactive API documentation at http://127.0.0.1:8000/docs
"""

from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.exc import DataError, IntegrityError

from app import lookups, papers, reviews, sessions, users
from app.checks import RuleError
from app.database import engine

app = FastAPI(
    title="Research Conference and Paper Review Management System",
    description=(
        "Create, read, update and delete users, papers, reviews and sessions.\n\n"
        "Rejected requests answer with status 409 and a clear message. "
        "Nothing is saved when a request is rejected."
    ),
)

app.include_router(users.router)
app.include_router(papers.router)
app.include_router(reviews.router)
app.include_router(sessions.router)
app.include_router(lookups.router)

# The simple web pages (HTML, CSS, JavaScript) in app/static are served under /ui/
app.mount("/ui", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="ui")


# ---------------------------------------------------------------
# Clear error messages
# ---------------------------------------------------------------
@app.exception_handler(RuleError)
def handle_rule_error(request: Request, error: RuleError):
    """One of our own checks (self-review, session assignment, ...) said no."""
    return JSONResponse(status_code=409, content={"detail": str(error)})


@app.exception_handler(IntegrityError)
def handle_integrity_error(request: Request, error: IntegrityError):
    """The database refused: duplicate value, missing parent row, CHECK failed, row still in use..."""
    first_lines = " ".join(str(error.orig).strip().split("\n")[:2])
    return JSONResponse(status_code=409, content={"detail": f"Database rejected the change: {first_lines}"})


@app.exception_handler(DataError)
def handle_data_error(request: Request, error: DataError):
    """A value has the wrong format or is too long for its column."""
    first_line = str(error.orig).strip().split("\n")[0]
    return JSONResponse(status_code=400, content={"detail": f"Invalid value: {first_line}"})


# ---------------------------------------------------------------
# Small extra endpoints
# ---------------------------------------------------------------
@app.get("/", include_in_schema=False)
def home():
    return RedirectResponse("/ui/")


@app.get("/health", tags=["Health"], summary="Check that the app can reach the database")
def health():
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return {"status": "ok"}
