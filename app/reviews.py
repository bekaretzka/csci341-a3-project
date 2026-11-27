"""Reviews (Create, Read, Update, Delete)."""

from datetime import date

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlalchemy import text

from app.checks import check_no_self_review
from app.database import engine, get_one, provided_fields, to_dicts, update_row

router = APIRouter(prefix="/reviews", tags=["Reviews"])


class ReviewCreate(BaseModel):
    paper_id: int
    reviewer_id: int
    overall_score: int                 # 1 to 5 (checked by the database)
    recommendation: str                # 'accept' or 'reject' (checked by the database)
    comments_for_authors: str
    confidential_comments: str | None = None
    review_submission_date: date | None = None   # today if left out


class ReviewUpdate(BaseModel):
    """Every field is optional. Only the fields you send are changed."""
    paper_id: int | None = None
    reviewer_id: int | None = None
    overall_score: int | None = None
    recommendation: str | None = None
    comments_for_authors: str | None = None
    confidential_comments: str | None = None
    review_submission_date: date | None = None


REVIEW_COLUMNS = [
    "paper_id", "reviewer_id", "overall_score", "recommendation",
    "comments_for_authors", "confidential_comments", "review_submission_date",
]

SELECT_REVIEW = """
    SELECT r.review_id, r.paper_id, p.title AS paper_title,
           r.reviewer_id, u.name || ' ' || u.surname AS reviewer_name,
           r.overall_score, r.recommendation, r.comments_for_authors,
           r.confidential_comments, r.review_submission_date
    FROM review r
    JOIN paper p ON p.paper_id = r.paper_id
    JOIN app_user u ON u.user_id = r.reviewer_id
    """


def fetch_review(conn, review_id):
    return get_one(conn, SELECT_REVIEW + " WHERE r.review_id = :id", {"id": review_id},
                   f"Review {review_id} not found.")


@router.post("", status_code=201, summary="Create a review (self-reviews are rejected)")
def create_review(data: ReviewCreate):
    with engine.begin() as conn:
        # Check 1: the reviewer must not be an author of the paper.
        check_no_self_review(conn, data.paper_id, data.reviewer_id)

        review_id = conn.execute(
            text("""
                INSERT INTO review (paper_id, reviewer_id, overall_score, recommendation,
                                    comments_for_authors, confidential_comments, review_submission_date)
                VALUES (:paper_id, :reviewer_id, :overall_score, :recommendation,
                        :comments_for_authors, :confidential_comments,
                        COALESCE(:review_submission_date, CURRENT_DATE))
                RETURNING review_id
                """),
            data.model_dump(),
        ).scalar_one()
        return fetch_review(conn, review_id)


@router.get("", summary="List reviews (optional filters)")
def list_reviews(paper_id: int | None = None, reviewer_id: int | None = None):
    with engine.connect() as conn:
        return to_dicts(conn.execute(
            text(SELECT_REVIEW + """
                WHERE (:paper_id IS NULL OR r.paper_id = :paper_id)
                  AND (:reviewer_id IS NULL OR r.reviewer_id = :reviewer_id)
                ORDER BY r.review_id
                """),
            {"paper_id": paper_id, "reviewer_id": reviewer_id},
        ))


@router.get("/{review_id}", summary="Get one review")
def get_review(review_id: int):
    with engine.connect() as conn:
        return fetch_review(conn, review_id)


@router.put("/{review_id}", summary="Update a review (send only the fields to change)")
def update_review(review_id: int, data: ReviewUpdate):
    with engine.begin() as conn:
        current = get_one(conn, "SELECT * FROM review WHERE review_id = :id", {"id": review_id},
                          f"Review {review_id} not found.")
        changes = provided_fields(data, REVIEW_COLUMNS)

        # Check 1 again, for the paper and reviewer the review will have after the change.
        check_no_self_review(
            conn,
            changes.get("paper_id", current["paper_id"]),
            changes.get("reviewer_id", current["reviewer_id"]),
        )

        update_row(conn, "review", "review_id", review_id, changes)
        return fetch_review(conn, review_id)


@router.delete("/{review_id}", summary="Delete a review")
def delete_review(review_id: int):
    with engine.begin() as conn:
        deleted = conn.execute(text("DELETE FROM review WHERE review_id = :id"), {"id": review_id})
        if deleted.rowcount == 0:
            raise HTTPException(status_code=404, detail=f"Review {review_id} not found.")
    return {"deleted_review_id": review_id}
