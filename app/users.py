"""Users, with their author and reviewer profiles (Create, Read, Update, Delete)."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import text

from app.checks import RuleError
from app.database import engine, get_one, insert_many, to_dicts, update_row

router = APIRouter(prefix="/users", tags=["Users"])


# ---------------------------------------------------------------
# What the client sends
# ---------------------------------------------------------------
class AuthorProfile(BaseModel):
    orcid: str | None = None
    research_areas: list[str] = []


class ReviewerProfile(BaseModel):
    years_experience: int
    expertise: list[str] = []


class UserIn(BaseModel):
    name: str
    surname: str
    email: str
    affiliation: str
    country: str
    phone: str = Field(min_length=1, max_length=30)
    author: AuthorProfile | None = None      # leave out if the user is not an author
    reviewer: ReviewerProfile | None = None  # leave out if the user is not a reviewer


# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
def fetch_user(conn, user_id):
    """One user with the author and reviewer profiles (None if the user does not have one)."""
    user = get_one(
        conn,
        """
        SELECT user_id, name, surname, email, affiliation, country, phone
        FROM app_user WHERE user_id = :id
        """,
        {"id": user_id},
        f"User {user_id} not found.",
    )

    author = conn.execute(
        text("SELECT orcid FROM author WHERE author_id = :id"), {"id": user_id}
    ).mappings().first()
    if author is None:
        user["author"] = None
    else:
        areas = conn.execute(
            text("SELECT area_label FROM author_research_area WHERE author_id = :id ORDER BY area_label"),
            {"id": user_id},
        ).scalars().all()
        user["author"] = {"orcid": author["orcid"], "research_areas": list(areas)}

    reviewer = conn.execute(
        text("SELECT years_experience FROM reviewer WHERE reviewer_id = :id"), {"id": user_id}
    ).mappings().first()
    if reviewer is None:
        user["reviewer"] = None
    else:
        expertise = conn.execute(
            text("SELECT area_label FROM reviewer_expertise WHERE reviewer_id = :id ORDER BY area_label"),
            {"id": user_id},
        ).scalars().all()
        user["reviewer"] = {
            "years_experience": reviewer["years_experience"],
            "expertise": list(expertise),
        }

    return user


def save_profiles(conn, user_id, data):
    """Make the author / reviewer profiles of the user match what the client sent."""
    if data.author is None and data.reviewer is None:
        raise RuleError("A user must be an author, a reviewer, or both.")

    # --- author profile ---
    if data.author is not None:
        conn.execute(
            text("""
                INSERT INTO author (author_id, orcid) VALUES (:id, :orcid)
                ON CONFLICT (author_id) DO UPDATE SET orcid = EXCLUDED.orcid
                """),
            {"id": user_id, "orcid": data.author.orcid},
        )
        conn.execute(text("DELETE FROM author_research_area WHERE author_id = :id"), {"id": user_id})
        insert_many(
            conn,
            "INSERT INTO author_research_area (author_id, area_label) VALUES (:id, :label)",
            [{"id": user_id, "label": label} for label in sorted(set(data.author.research_areas))],
        )
    else:
        # Fails with a clear message if this author still has papers (RESTRICT).
        conn.execute(text("DELETE FROM author WHERE author_id = :id"), {"id": user_id})

    # --- reviewer profile ---
    if data.reviewer is not None:
        conn.execute(
            text("""
                INSERT INTO reviewer (reviewer_id, years_experience) VALUES (:id, :years)
                ON CONFLICT (reviewer_id) DO UPDATE SET years_experience = EXCLUDED.years_experience
                """),
            {"id": user_id, "years": data.reviewer.years_experience},
        )
        conn.execute(text("DELETE FROM reviewer_expertise WHERE reviewer_id = :id"), {"id": user_id})
        insert_many(
            conn,
            "INSERT INTO reviewer_expertise (reviewer_id, area_label) VALUES (:id, :label)",
            [{"id": user_id, "label": label} for label in sorted(set(data.reviewer.expertise))],
        )
    else:
        # Fails with a clear message if this reviewer still has reviews, tracks or sessions.
        conn.execute(text("DELETE FROM reviewer WHERE reviewer_id = :id"), {"id": user_id})


BASIC_FIELDS = ["name", "surname", "email", "affiliation", "country", "phone"]


# ---------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------
@router.post("", status_code=201, summary="Create a user (with author and/or reviewer profile)")
def create_user(data: UserIn):
    with engine.begin() as conn:  # one transaction: everything is saved or nothing is
        if data.author is None and data.reviewer is None:
            raise RuleError("A user must be an author, a reviewer, or both.")
        user_id = conn.execute(
            text("""
                INSERT INTO app_user (name, surname, email, affiliation, country, phone)
                VALUES (:name, :surname, :email, :affiliation, :country, :phone)
                RETURNING user_id
                """),
            {field: getattr(data, field) for field in BASIC_FIELDS},
        ).scalar_one()
        save_profiles(conn, user_id, data)
        return fetch_user(conn, user_id)


@router.get("", summary="List all users")
def list_users():
    with engine.connect() as conn:
        return to_dicts(conn.execute(text("""
            SELECT u.user_id, u.name, u.surname, u.email, u.affiliation, u.country, u.phone,
                   (a.author_id IS NOT NULL)   AS is_author,
                   (r.reviewer_id IS NOT NULL) AS is_reviewer
            FROM app_user u
            LEFT JOIN author a   ON a.author_id = u.user_id
            LEFT JOIN reviewer r ON r.reviewer_id = u.user_id
            ORDER BY u.user_id
            """)))


@router.get("/{user_id}", summary="Get one user with profiles")
def get_user(user_id: int):
    with engine.connect() as conn:
        return fetch_user(conn, user_id)


@router.put("/{user_id}", summary="Update a user (send the full user, profiles included)")
def update_user(user_id: int, data: UserIn):
    with engine.begin() as conn:
        fetch_user(conn, user_id)  # 404 if the user does not exist
        if data.author is None and data.reviewer is None:
            raise RuleError("A user must be an author, a reviewer, or both.")
        update_row(conn, "app_user", "user_id", user_id,
                   {field: getattr(data, field) for field in BASIC_FIELDS})
        save_profiles(conn, user_id, data)
        return fetch_user(conn, user_id)


@router.delete("/{user_id}", summary="Delete a user")
def delete_user(user_id: int):
    with engine.begin() as conn:
        # A user who still has papers, reviews, tracks or sessions is refused by the database.
        deleted = conn.execute(text("DELETE FROM app_user WHERE user_id = :id"), {"id": user_id})
        if deleted.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"User {user_id} not found.")
    return {"deleted_user_id": user_id}
