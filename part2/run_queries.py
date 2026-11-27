"""
CSCI 341 Assignment 3 - Part 2: SQL operations through Python and SQLAlchemy.

Run from the project root:
    python part2/run_queries.py

The script prints every task number, the SQL it runs, and the result.
Updates and deletes are shown before and after, then rolled back, so every
task starts from the original sample data.
"""

from pathlib import Path
from textwrap import dedent

from sqlalchemy import text

from db import engine, run_sql_file


ARMAN_EMAIL = "arman.armanov@example.com"
ARMAN_NEW_PHONE = "+77773414141"
AMINA_EMAIL = "amina.aminova@example.com"
ASTANA = "Astana"
SELECTED_PAPER_ID = 1       # task 5.3
SELECTED_CONFERENCE_ID = 1  # task 5.4
EXPERTISE = "Databases"     # task 5.4
MIN_YEARS = 3               # task 5.4
SEARCH_PATTERN = "%machine learning%"  # task 5.2

TABLES = [
    "app_user", "author", "reviewer", "author_research_area", "reviewer_expertise",
    "conference", "conference_host", "conference_reviewer", "track",
    "conference_session", "paper", "paper_keyword", "paper_author",
    "paper_version", "review",
]


# ---------------------------------------------------------------
# Small helpers for printing
# ---------------------------------------------------------------
def heading(title):
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def print_table(columns, rows):
    """Print rows as a simple text table (None is shown as NULL)."""
    cells = [["NULL" if v is None else str(v) for v in row] for row in rows]
    widths = [len(c) for c in columns]
    for row in cells:
        for i, value in enumerate(row):
            widths[i] = max(widths[i], len(value))
    line = " | ".join(c.ljust(widths[i]) for i, c in enumerate(columns))
    print(line)
    print("-+-".join("-" * w for w in widths))
    for row in cells:
        print(" | ".join(v.ljust(widths[i]) for i, v in enumerate(row)))
    print(f"({len(rows)} rows)")


def run(conn, sql, params=None):
    """Show the SQL and its parameters, run it, and show the result."""
    params = params or {}
    print()
    print(dedent(sql).strip())
    if params:
        print("Parameters:", params)
    result = conn.execute(text(sql), params)
    if result.returns_rows:
        print_table(list(result.keys()), result.fetchall())
    else:
        print(f"Rows affected: {result.rowcount}")
    return result


def run_select(sql, params=None):
    """Run one SELECT in its own connection."""
    with engine.connect() as conn:
        run(conn, sql, params)


def demo_change(show_queries, change_sql, change_params):
    """
    Show data BEFORE, run the change, show data AFTER, then roll back
    and show the data once more to prove the original data is back.
    """
    with engine.connect() as conn:
        transaction = conn.begin()
        try:
            print("\n--- BEFORE ---")
            for sql, params in show_queries:
                run(conn, sql, params)
            print("\n--- CHANGE ---")
            run(conn, change_sql, change_params)
            print("\n--- AFTER ---")
            for sql, params in show_queries:
                run(conn, sql, params)
        finally:
            transaction.rollback()  # undo the change
    print("\n--- ROLLED BACK: original data restored ---")
    for sql, params in show_queries:
        run_select(sql, params)


# ---------------------------------------------------------------
# Tasks 1 and 2: create tables and insert data
# ---------------------------------------------------------------
def task_1_create():
    heading("Task 1: Create tables (runs db/schema.sql)")
    run_sql_file("db/schema.sql")
    print("\nTables created in the current schema:")
    run_select("""
        SELECT schemaname AS schema_name, tablename AS table_name
        FROM pg_catalog.pg_tables
        WHERE schemaname = current_schema() AND tablename = ANY(:table_names)
        ORDER BY tablename
        """, {"table_names": TABLES})


def task_2_insert():
    heading("Task 2: Insert sample data (runs db/seed.sql)")
    run_sql_file("db/seed.sql")
    print("\nSample data inserted. Row count of every table:")
    counts = " UNION ALL ".join(
        f"SELECT '{name}' AS table_name, COUNT(*) AS row_count FROM {name}" for name in TABLES
    )
    run_select(counts)
    print("\nTo restore the original data: run db/schema.sql, then db/seed.sql "
          "(or run this script again).")


# ---------------------------------------------------------------
# Task 3: updates
# ---------------------------------------------------------------
def task_3_updates():
    heading("Task 3.1: Update Arman Armanov's phone number")
    demo_change(
        show_queries=[(
            "SELECT user_id, name, surname, email, phone FROM app_user WHERE email = :email",
            {"email": ARMAN_EMAIL},
        )],
        change_sql="UPDATE app_user SET phone = :phone WHERE email = :email",
        change_params={"phone": ARMAN_NEW_PHONE, "email": ARMAN_EMAIL},
    )

    heading("Task 3.2: Extend review deadlines (Astana +7 days, other cities +3 days)")
    demo_change(
        show_queries=[(
            """
            SELECT conference_id, acronym, city, review_deadline
            FROM conference
            ORDER BY conference_id
            """,
            None,
        )],
        change_sql="""
            UPDATE conference
            SET review_deadline = review_deadline +
                CASE WHEN city = :city THEN 7 ELSE 3 END
            """,
        change_params={"city": ASTANA},
    )


# ---------------------------------------------------------------
# Task 4: deletes
# ---------------------------------------------------------------
def task_4_deletes():
    heading("Task 4.1: Delete Amina's withdrawn papers (she is the corresponding author)")
    # Dependent rows (authors, keywords, versions, reviews) go away by ON DELETE CASCADE.
    demo_change(
        show_queries=[
            ("""
             SELECT p.paper_id, p.title, p.status, pa.is_corresponding,
                    (SELECT COUNT(*) FROM paper_keyword k WHERE k.paper_id = p.paper_id) AS keywords,
                    (SELECT COUNT(*) FROM paper_version v WHERE v.paper_id = p.paper_id) AS versions,
                    (SELECT COUNT(*) FROM review r WHERE r.paper_id = p.paper_id) AS reviews
             FROM paper p
             JOIN paper_author pa ON pa.paper_id = p.paper_id
             JOIN app_user u ON u.user_id = pa.author_id
             WHERE u.email = :email
             ORDER BY p.paper_id
             """, {"email": AMINA_EMAIL}),
            ("""
             SELECT (SELECT COUNT(*) FROM app_user)       AS users,
                    (SELECT COUNT(*) FROM conference)     AS conferences,
                    (SELECT COUNT(*) FROM track)          AS tracks,
                    (SELECT COUNT(*) FROM paper)          AS papers,
                    (SELECT COUNT(*) FROM paper_author)   AS authorships,
                    (SELECT COUNT(*) FROM paper_keyword)  AS keywords,
                    (SELECT COUNT(*) FROM paper_version)  AS versions,
                    (SELECT COUNT(*) FROM review)         AS reviews
             """, None),
        ],
        change_sql="""
            DELETE FROM paper
            WHERE status = 'withdrawn'
              AND paper_id IN (
                  SELECT pa.paper_id
                  FROM paper_author pa
                  JOIN app_user u ON u.user_id = pa.author_id
                  WHERE pa.is_corresponding AND u.email = :email
              )
            """,
        change_params={"email": AMINA_EMAIL},
    )

    heading("Task 4.2: Delete empty sessions of conferences held in Astana")
    demo_change(
        show_queries=[(
            """
            SELECT s.session_id, s.title, c.acronym, c.city, COUNT(p.paper_id) AS papers
            FROM conference_session s
            JOIN conference c ON c.conference_id = s.conference_id
            LEFT JOIN paper p ON p.session_id = s.session_id
            GROUP BY s.session_id, s.title, c.acronym, c.city
            ORDER BY s.session_id
            """,
            None,
        )],
        change_sql="""
            DELETE FROM conference_session
            WHERE conference_id IN (SELECT conference_id FROM conference WHERE city = :city)
              AND NOT EXISTS (
                  SELECT 1 FROM paper p WHERE p.session_id = conference_session.session_id
              )
            """,
        change_params={"city": ASTANA},
    )


# ---------------------------------------------------------------
# Task 5: simple queries
# ---------------------------------------------------------------
def task_5_simple_queries():
    heading("Task 5.1: Accepted papers with corresponding author, track and conference")
    run_select("""
        SELECT p.paper_id, p.title,
               u.name || ' ' || u.surname AS corresponding_author,
               u.email,
               t.name AS track_name,
               c.conference_id, c.acronym
        FROM paper p
        JOIN paper_author pa ON pa.paper_id = p.paper_id AND pa.is_corresponding
        JOIN app_user u      ON u.user_id = pa.author_id
        JOIN track t         ON t.track_id = p.track_id
        JOIN conference c    ON c.conference_id = t.conference_id
        WHERE p.status = 'accepted'
        ORDER BY p.paper_id
        """)

    heading("Task 5.2: Papers whose abstract contains 'machine learning' (case-insensitive)")
    run_select("""
        SELECT paper_id, title
        FROM paper
        WHERE abstract ILIKE :pattern
        ORDER BY paper_id
        """, {"pattern": SEARCH_PATTERN})

    heading("Task 5.3: All versions of one paper, newest first")
    run_select("""
        SELECT version_no, file_location, uploaded_at
        FROM paper_version
        WHERE paper_id = :paper_id
        ORDER BY version_no DESC
        """, {"paper_id": SELECTED_PAPER_ID})

    heading("Task 5.4: Reviewers in a conference pool with Databases expertise and 3+ years")
    run_select("""
        SELECT DISTINCT r.reviewer_id, u.name || ' ' || u.surname AS full_name, u.email
        FROM conference_reviewer cr
        JOIN reviewer r           ON r.reviewer_id = cr.reviewer_id
        JOIN app_user u           ON u.user_id = r.reviewer_id
        JOIN reviewer_expertise e ON e.reviewer_id = r.reviewer_id
        WHERE cr.conference_id = :conference_id
          AND e.area_label = :expertise
          AND r.years_experience >= :min_years
        ORDER BY r.reviewer_id
        """, {"conference_id": SELECTED_CONFERENCE_ID, "expertise": EXPERTISE, "min_years": MIN_YEARS})


# ---------------------------------------------------------------
# Task 6: complex queries
# ---------------------------------------------------------------
def task_6_complex_queries():
    heading("Task 6.1: Papers and distinct authors per track (empty tracks show 0)")
    run_select("""
        SELECT t.track_id, t.name, t.conference_id,
               COUNT(DISTINCT p.paper_id)   AS papers,
               COUNT(DISTINCT pa.author_id) AS authors
        FROM track t
        LEFT JOIN paper p         ON p.track_id = t.track_id
        LEFT JOIN paper_author pa ON pa.paper_id = p.paper_id
        GROUP BY t.track_id, t.name, t.conference_id
        ORDER BY t.track_id
        """)

    heading("Task 6.2: Review count and average score per reviewer")
    run_select("""
        SELECT r.reviewer_id,
               u.name || ' ' || u.surname AS full_name,
               COUNT(v.review_id)         AS reviews,
               ROUND(AVG(v.overall_score), 2) AS avg_score
        FROM reviewer r
        JOIN app_user u    ON u.user_id = r.reviewer_id
        LEFT JOIN review v ON v.reviewer_id = r.reviewer_id
        GROUP BY r.reviewer_id, u.name, u.surname
        ORDER BY r.reviewer_id
        """)

    heading("Task 6.3: Papers, accepted papers and average review score per conference")
    # Each number is its own small subquery, so joins cannot multiply the counts.
    run_select("""
        SELECT c.conference_id, c.acronym,
               (SELECT COUNT(*)
                FROM paper p JOIN track t ON t.track_id = p.track_id
                WHERE t.conference_id = c.conference_id) AS total_papers,
               (SELECT COUNT(*)
                FROM paper p JOIN track t ON t.track_id = p.track_id
                WHERE t.conference_id = c.conference_id AND p.status = 'accepted') AS accepted_papers,
               (SELECT ROUND(AVG(v.overall_score), 2)
                FROM review v
                JOIN paper p ON p.paper_id = v.paper_id
                JOIN track t ON t.track_id = p.track_id
                WHERE t.conference_id = c.conference_id) AS avg_score
        FROM conference c
        ORDER BY c.conference_id
        """)

    heading("Task 6.4: Reviewers with more reviews than the average reviewer")
    run_select("""
        WITH reviewer_counts AS (
            SELECT r.reviewer_id, COUNT(v.review_id) AS review_count
            FROM reviewer r
            LEFT JOIN review v ON v.reviewer_id = r.reviewer_id
            GROUP BY r.reviewer_id
        ),
        overall AS (
            SELECT AVG(review_count) AS avg_count FROM reviewer_counts
        )
        SELECT rc.reviewer_id,
               u.name || ' ' || u.surname AS full_name,
               rc.review_count,
               ROUND(o.avg_count, 2) AS overall_average
        FROM reviewer_counts rc
        JOIN app_user u ON u.user_id = rc.reviewer_id
        CROSS JOIN overall o
        WHERE rc.review_count > o.avg_count
        ORDER BY rc.reviewer_id
        """)


# ---------------------------------------------------------------
# Task 7: derived attribute
# ---------------------------------------------------------------
def task_7_acceptance_rate():
    heading("Task 7: Acceptance rate per conference (accepted / (accepted + rejected))")
    run_select("""
        SELECT c.conference_id, c.acronym,
               COUNT(p.paper_id) FILTER (WHERE p.status = 'accepted') AS accepted,
               COUNT(p.paper_id) FILTER (WHERE p.status = 'rejected') AS rejected,
               ROUND(
                   100.0 * COUNT(p.paper_id) FILTER (WHERE p.status = 'accepted')
                   / NULLIF(COUNT(p.paper_id) FILTER (WHERE p.status IN ('accepted', 'rejected')), 0),
                   2
               ) AS acceptance_rate
        FROM conference c
        LEFT JOIN track t ON t.conference_id = c.conference_id
        LEFT JOIN paper p ON p.track_id = t.track_id
        GROUP BY c.conference_id, c.acronym
        ORDER BY c.conference_id
        """)


# ---------------------------------------------------------------
# Task 8: view
# ---------------------------------------------------------------
def task_8_view():
    heading("Task 8: Create and query the view accepted_paper_schedule")
    view_file = Path("db/view.sql")
    print("\n" + view_file.read_text(encoding="utf-8").strip())
    with engine.begin() as conn:  # begin() commits when the block ends
        conn.execute(text(view_file.read_text(encoding="utf-8")))
    print("\nView created.")
    run_select("""
        SELECT *
        FROM accepted_paper_schedule
        ORDER BY conference_id, session_date, start_time, session_id, paper_id
        """)


def main():
    task_1_create()
    task_2_insert()
    task_3_updates()
    task_4_deletes()
    task_5_simple_queries()
    task_6_complex_queries()
    task_7_acceptance_rate()
    task_8_view()
    print("\nDone.")


if __name__ == "__main__":
    main()
