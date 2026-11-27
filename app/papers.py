"""Papers, with authorship, keywords and versions (Create, Read, Update, Delete)."""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlalchemy import text

from app.checks import RuleError, check_new_authors_did_not_review, check_session_assignment
from app.database import engine, get_one, insert_many, provided_fields, to_dicts, update_row

router = APIRouter(prefix="/papers", tags=["Papers"])


# ---------------------------------------------------------------
# What the client sends
# ---------------------------------------------------------------
class AuthorshipIn(BaseModel):
    author_id: int
    author_position: int
    is_corresponding: bool = False


class VersionIn(BaseModel):
    version_no: int
    file_location: str          # only a file location is stored, no real upload
    change_note: str | None = None


class VersionUpdate(BaseModel):
    file_location: str | None = None
    change_note: str | None = None


class PaperCreate(BaseModel):
    track_id: int
    title: str
    abstract: str
    status: str = "submitted"
    session_id: int | None = None
    authors: list[AuthorshipIn]
    keywords: list[str] = []
    versions: list[VersionIn]


class PaperUpdate(BaseModel):
    """Every field is optional. Only the fields you send are changed."""
    track_id: int | None = None
    title: str | None = None
    abstract: str | None = None
    status: str | None = None
    session_id: int | None = None                # send null to remove the paper from its session
    authors: list[AuthorshipIn] | None = None    # replaces the whole author list
    keywords: list[str] | None = None            # replaces the whole keyword list


PAPER_COLUMNS = ["track_id", "title", "abstract", "status", "session_id"]


# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
def fetch_paper(conn, paper_id):
    """One paper with its authors, keywords and versions."""
    paper = get_one(
        conn,
        """
        SELECT p.paper_id, p.title, p.abstract, p.status, p.submission_date,
               p.track_id, t.name AS track_name, t.conference_id, p.session_id
        FROM paper p
        JOIN track t ON t.track_id = p.track_id
        WHERE p.paper_id = :id
        """,
        {"id": paper_id},
        f"Paper {paper_id} not found.",
    )
    paper["authors"] = to_dicts(conn.execute(text("""
        SELECT pa.author_id, u.name || ' ' || u.surname AS full_name,
               pa.author_position, pa.is_corresponding
        FROM paper_author pa
        JOIN app_user u ON u.user_id = pa.author_id
        WHERE pa.paper_id = :id
        ORDER BY pa.author_position
        """), {"id": paper_id}))
    paper["keywords"] = list(conn.execute(
        text("SELECT keyword FROM paper_keyword WHERE paper_id = :id ORDER BY keyword"),
        {"id": paper_id},
    ).scalars().all())
    paper["versions"] = to_dicts(conn.execute(text("""
        SELECT version_no, file_location, uploaded_at, change_note
        FROM paper_version WHERE paper_id = :id
        ORDER BY version_no DESC
        """), {"id": paper_id}))
    # The current version is the one with the highest number.
    paper["current_version"] = paper["versions"][0]["version_no"] if paper["versions"] else None
    return paper


def check_author_list(authors):
    """A paper needs at least one author and exactly one corresponding author."""
    if not authors:
        raise RuleError("A paper needs at least one author.")
    corresponding = [a for a in authors if a.is_corresponding]
    if len(corresponding) != 1:
        raise RuleError("A paper needs exactly one corresponding author.")


def save_authors(conn, paper_id, authors):
    conn.execute(text("DELETE FROM paper_author WHERE paper_id = :id"), {"id": paper_id})
    insert_many(
        conn,
        """
        INSERT INTO paper_author (paper_id, author_id, author_position, is_corresponding)
        VALUES (:paper_id, :author_id, :author_position, :is_corresponding)
        """,
        [{"paper_id": paper_id, **a.model_dump()} for a in authors],
    )


def save_keywords(conn, paper_id, keywords):
    conn.execute(text("DELETE FROM paper_keyword WHERE paper_id = :id"), {"id": paper_id})
    insert_many(
        conn,
        "INSERT INTO paper_keyword (paper_id, keyword) VALUES (:paper_id, :keyword)",
        [{"paper_id": paper_id, "keyword": k} for k in sorted(set(keywords))],
    )


# ---------------------------------------------------------------
# Paper endpoints
# ---------------------------------------------------------------
@router.post("", status_code=201, summary="Create a paper (with authors, keywords, versions)")
def create_paper(data: PaperCreate):
    with engine.begin() as conn:  # one transaction for the paper and everything attached to it
        check_author_list(data.authors)
        if not data.versions:
            raise RuleError("A paper needs at least one version.")
        check_session_assignment(conn, data.status, data.track_id, data.session_id)

        paper_id = conn.execute(
            text("""
                INSERT INTO paper (track_id, title, abstract, status, session_id)
                VALUES (:track_id, :title, :abstract, :status, :session_id)
                RETURNING paper_id
                """),
            {field: getattr(data, field) for field in PAPER_COLUMNS},
        ).scalar_one()

        save_authors(conn, paper_id, data.authors)
        save_keywords(conn, paper_id, data.keywords)
        insert_many(
            conn,
            """
            INSERT INTO paper_version (paper_id, version_no, file_location, change_note)
            VALUES (:paper_id, :version_no, :file_location, :change_note)
            """,
            [{"paper_id": paper_id, **v.model_dump()} for v in data.versions],
        )
        return fetch_paper(conn, paper_id)


@router.get("", summary="List papers (optional filters)")
def list_papers(status: str | None = None, conference_id: int | None = None, track_id: int | None = None):
    with engine.connect() as conn:
        return to_dicts(conn.execute(
            text("""
                SELECT p.paper_id, p.title, p.status, p.track_id, t.conference_id, p.session_id,
                       (SELECT MAX(v.version_no) FROM paper_version v
                        WHERE v.paper_id = p.paper_id) AS current_version
                FROM paper p
                JOIN track t ON t.track_id = p.track_id
                WHERE (:status IS NULL OR p.status = :status)
                  AND (:conference_id IS NULL OR t.conference_id = :conference_id)
                  AND (:track_id IS NULL OR p.track_id = :track_id)
                ORDER BY p.paper_id
                """),
            {"status": status, "conference_id": conference_id, "track_id": track_id},
        ))


@router.get("/{paper_id}", summary="Get one paper with authors, keywords and versions")
def get_paper(paper_id: int):
    with engine.connect() as conn:
        return fetch_paper(conn, paper_id)


@router.put("/{paper_id}", summary="Update a paper (send only the fields to change)")
def update_paper(paper_id: int, data: PaperUpdate):
    with engine.begin() as conn:
        current = fetch_paper(conn, paper_id)  # 404 if missing

        changes = provided_fields(data, PAPER_COLUMNS)

        # Check 2: the paper as it WOULD be after this change must have a valid session.
        new_status = changes.get("status", current["status"])
        new_track_id = changes.get("track_id", current["track_id"])
        new_session_id = changes.get("session_id", current["session_id"])
        check_session_assignment(conn, new_status, new_track_id, new_session_id)

        update_row(conn, "paper", "paper_id", paper_id, changes)

        if "authors" in data.model_fields_set and data.authors is not None:
            check_author_list(data.authors)
            # Check 1 (second part): a reviewer of this paper cannot become one of its authors.
            check_new_authors_did_not_review(conn, paper_id, [a.author_id for a in data.authors])
            save_authors(conn, paper_id, data.authors)

        if "keywords" in data.model_fields_set and data.keywords is not None:
            save_keywords(conn, paper_id, data.keywords)

        return fetch_paper(conn, paper_id)


@router.delete("/{paper_id}", summary="Delete a paper (its versions, authors, keywords and reviews go too)")
def delete_paper(paper_id: int):
    with engine.begin() as conn:
        deleted = conn.execute(text("DELETE FROM paper WHERE paper_id = :id"), {"id": paper_id})
        if deleted.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Paper {paper_id} not found.")
    return {"deleted_paper_id": paper_id}


# ---------------------------------------------------------------
# Version endpoints
# ---------------------------------------------------------------
@router.post("/{paper_id}/versions", status_code=201, summary="Add a version to a paper")
def add_version(paper_id: int, data: VersionIn):
    with engine.begin() as conn:
        fetch_paper(conn, paper_id)  # 404 if missing
        conn.execute(
            text("""
                INSERT INTO paper_version (paper_id, version_no, file_location, change_note)
                VALUES (:paper_id, :version_no, :file_location, :change_note)
                """),
            {"paper_id": paper_id, **data.model_dump()},
        )
        return fetch_paper(conn, paper_id)


@router.put("/{paper_id}/versions/{version_no}", summary="Update a version's file location or note")
def update_version(paper_id: int, version_no: int, data: VersionUpdate):
    with engine.begin() as conn:
        get_one(conn,
                "SELECT version_no FROM paper_version WHERE paper_id = :p AND version_no = :v",
                {"p": paper_id, "v": version_no},
                f"Version {version_no} of paper {paper_id} not found.")
        changes = provided_fields(data, ["file_location", "change_note"])
        if changes:
            set_clause = ", ".join(f"{column} = :{column}" for column in changes)
            conn.execute(
                text(f"UPDATE paper_version SET {set_clause} WHERE paper_id = :paper_id AND version_no = :version_no"),
                {**changes, "paper_id": paper_id, "version_no": version_no},
            )
        return fetch_paper(conn, paper_id)


@router.delete("/{paper_id}/versions/{version_no}", summary="Delete a version")
def delete_version(paper_id: int, version_no: int):
    with engine.begin() as conn:
        count = conn.execute(
            text("SELECT COUNT(*) FROM paper_version WHERE paper_id = :id"), {"id": paper_id}
        ).scalar_one()
        if count <= 1:
            raise RuleError("A paper must keep at least one version.")
        deleted = conn.execute(
            text("DELETE FROM paper_version WHERE paper_id = :p AND version_no = :v"),
            {"p": paper_id, "v": version_no},
        )
        if deleted.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Version {version_no} of paper {paper_id} not found.")
        return fetch_paper(conn, paper_id)
