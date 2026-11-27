"""Conference sessions (Create, Read, Update, Delete).

To put a paper into a session, update the paper (PUT /papers/{id}) with a session_id.
"""

from datetime import date, time

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlalchemy import text

from app.checks import check_session_conference_change
from app.database import engine, get_one, provided_fields, to_dicts, update_row

router = APIRouter(prefix="/sessions", tags=["Sessions"])


class SessionCreate(BaseModel):
    conference_id: int
    title: str
    session_date: date
    start_time: time
    end_time: time          # must be later than start_time (checked by the database)
    room_label: str
    chair_id: int           # a reviewer


class SessionUpdate(BaseModel):
    """Every field is optional. Only the fields you send are changed."""
    conference_id: int | None = None
    title: str | None = None
    session_date: date | None = None
    start_time: time | None = None
    end_time: time | None = None
    room_label: str | None = None
    chair_id: int | None = None


SESSION_COLUMNS = ["conference_id", "title", "session_date", "start_time", "end_time", "room_label", "chair_id"]

SELECT_SESSION = """
    SELECT s.session_id, s.conference_id, c.acronym, s.title, s.session_date,
           s.start_time, s.end_time, s.room_label,
           s.chair_id, u.name || ' ' || u.surname AS chair_name
    FROM conference_session s
    JOIN conference c ON c.conference_id = s.conference_id
    JOIN app_user u ON u.user_id = s.chair_id
    """


def fetch_session(conn, session_id):
    """One session with the papers scheduled in it."""
    session = get_one(conn, SELECT_SESSION + " WHERE s.session_id = :id", {"id": session_id},
                      f"Session {session_id} not found.")
    session["papers"] = to_dicts(conn.execute(
        text("SELECT paper_id, title, status FROM paper WHERE session_id = :id ORDER BY paper_id"),
        {"id": session_id},
    ))
    return session


@router.post("", status_code=201, summary="Create a session")
def create_session(data: SessionCreate):
    with engine.begin() as conn:
        session_id = conn.execute(
            text("""
                INSERT INTO conference_session
                    (conference_id, title, session_date, start_time, end_time, room_label, chair_id)
                VALUES (:conference_id, :title, :session_date, :start_time, :end_time, :room_label, :chair_id)
                RETURNING session_id
                """),
            data.model_dump(),
        ).scalar_one()
        return fetch_session(conn, session_id)


@router.get("", summary="List sessions (optional filter by conference)")
def list_sessions(conference_id: int | None = None):
    with engine.connect() as conn:
        return to_dicts(conn.execute(
            text(SELECT_SESSION + """
                WHERE (:conference_id IS NULL OR s.conference_id = :conference_id)
                ORDER BY s.session_id
                """),
            {"conference_id": conference_id},
        ))


@router.get("/{session_id}", summary="Get one session with its papers")
def get_session(session_id: int):
    with engine.connect() as conn:
        return fetch_session(conn, session_id)


@router.put("/{session_id}", summary="Update a session (send only the fields to change)")
def update_session(session_id: int, data: SessionUpdate):
    with engine.begin() as conn:
        fetch_session(conn, session_id)  # 404 if missing
        changes = provided_fields(data, SESSION_COLUMNS)

        # Check 2: if the session moves to another conference, its papers must still fit.
        if "conference_id" in changes:
            check_session_conference_change(conn, session_id, changes["conference_id"])

        update_row(conn, "conference_session", "session_id", session_id, changes)
        return fetch_session(conn, session_id)


@router.delete("/{session_id}", summary="Delete a session (its papers stay, unscheduled)")
def delete_session(session_id: int):
    with engine.begin() as conn:
        deleted = conn.execute(
            text("DELETE FROM conference_session WHERE session_id = :id"), {"id": session_id}
        )
        if deleted.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Session {session_id} not found.")
    return {"deleted_session_id": session_id}
