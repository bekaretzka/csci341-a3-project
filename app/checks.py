"""
The two application checks required by the assignment (Part 1), plus a few
small rules. Every function raises RuleError when a rule is broken.
The endpoint stops, the transaction is rolled back, and the user sees the message.
"""

from sqlalchemy import text


class RuleError(Exception):
    """A business rule was broken. The message is shown to the user."""


# ---------------------------------------------------------------
# Check 1: no self-reviews
# ---------------------------------------------------------------
def check_no_self_review(conn, paper_id, reviewer_id):
    """Used when a review is saved: the reviewer must not be an author of the paper."""
    is_author = conn.execute(
        text("SELECT 1 FROM paper_author WHERE paper_id = :paper_id AND author_id = :reviewer_id"),
        {"paper_id": paper_id, "reviewer_id": reviewer_id},
    ).first()
    if is_author:
        raise RuleError(
            f"Self-review rejected: user {reviewer_id} is an author of paper {paper_id} "
            "and cannot review it."
        )


def check_new_authors_did_not_review(conn, paper_id, author_ids):
    """Used when a paper's authors change: nobody who already reviewed it may become an author."""
    clash = conn.execute(
        text("SELECT reviewer_id FROM review WHERE paper_id = :paper_id AND reviewer_id = ANY(:author_ids)"),
        {"paper_id": paper_id, "author_ids": list(author_ids)},
    ).first()
    if clash:
        raise RuleError(
            f"Author change rejected: user {clash[0]} has already reviewed paper {paper_id}, "
            "so they cannot also be one of its authors."
        )


# ---------------------------------------------------------------
# Check 2: valid session assignments
# ---------------------------------------------------------------
def check_session_assignment(conn, status, track_id, session_id):
    """
    A scheduled paper must be accepted, and its track and its session must
    belong to the same conference. Nothing to check if there is no session.
    """
    if session_id is None:
        return

    if status != "accepted":
        raise RuleError(
            f"Session assignment rejected: only accepted papers can be scheduled "
            f"(this paper's status is '{status}'). Remove the paper from its session first."
        )

    session = conn.execute(
        text("SELECT conference_id FROM conference_session WHERE session_id = :id"),
        {"id": session_id},
    ).first()
    if session is None:
        raise RuleError(f"Session {session_id} does not exist.")

    track = conn.execute(
        text("SELECT conference_id FROM track WHERE track_id = :id"),
        {"id": track_id},
    ).first()
    if track is None:
        raise RuleError(f"Track {track_id} does not exist.")

    if session.conference_id != track.conference_id:
        raise RuleError(
            f"Session assignment rejected: the paper's track belongs to conference "
            f"{track.conference_id}, but session {session_id} belongs to conference "
            f"{session.conference_id}."
        )


def check_session_conference_change(conn, session_id, new_conference_id):
    """If a session moves to another conference, none of its papers may belong to a different one."""
    wrong = conn.execute(
        text("""
            SELECT p.paper_id
            FROM paper p
            JOIN track t ON t.track_id = p.track_id
            WHERE p.session_id = :session_id AND t.conference_id <> :conference_id
            """),
        {"session_id": session_id, "conference_id": new_conference_id},
    ).first()
    if wrong:
        raise RuleError(
            f"Session change rejected: paper {wrong[0]} is scheduled in session {session_id} "
            f"but its track is not in conference {new_conference_id}."
        )
