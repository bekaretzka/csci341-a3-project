"""
Read-only lists for choosing values in the forms: conferences, tracks and reviewer pools.
These tables are filled by the seed script and are not edited through the web app.
"""

from fastapi import APIRouter
from sqlalchemy import text

from app.database import engine, get_one, to_dicts

router = APIRouter(tags=["Conferences and tracks (read only)"])


@router.get("/conferences", summary="List conferences with their host institutions")
def list_conferences():
    with engine.connect() as conn:
        conferences = to_dicts(conn.execute(text("""
            SELECT conference_id, name, acronym, description, city, country,
                   start_date, end_date, submission_deadline, review_deadline
            FROM conference ORDER BY conference_id
            """)))
        for conference in conferences:
            conference["hosts"] = list(conn.execute(
                text("SELECT host_name FROM conference_host WHERE conference_id = :id ORDER BY host_name"),
                {"id": conference["conference_id"]},
            ).scalars().all())
        return conferences


@router.get("/conferences/{conference_id}/reviewers", summary="Reviewer pool of a conference")
def reviewer_pool(conference_id: int):
    with engine.connect() as conn:
        get_one(conn, "SELECT conference_id FROM conference WHERE conference_id = :id",
                {"id": conference_id}, f"Conference {conference_id} not found.")
        return to_dicts(conn.execute(
            text("""
                SELECT r.reviewer_id, u.name || ' ' || u.surname AS full_name, u.email, r.years_experience
                FROM conference_reviewer cr
                JOIN reviewer r ON r.reviewer_id = cr.reviewer_id
                JOIN app_user u ON u.user_id = r.reviewer_id
                WHERE cr.conference_id = :id
                ORDER BY r.reviewer_id
                """),
            {"id": conference_id},
        ))


@router.get("/tracks", summary="List tracks (optional filter by conference)")
def list_tracks(conference_id: int | None = None):
    with engine.connect() as conn:
        return to_dicts(conn.execute(
            text("""
                SELECT track_id, conference_id, name, description, research_area, coordinator_id
                FROM track
                WHERE (:conference_id IS NULL OR conference_id = :conference_id)
                ORDER BY track_id
                """),
            {"conference_id": conference_id},
        ))
