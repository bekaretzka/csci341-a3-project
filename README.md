# Research Conference and Paper Review Management System

CSCI 341 Database Systems, Assignment 3 (Fall 2026).

A PostgreSQL database for research conferences and paper reviews, a Python/SQLAlchemy program that
runs the required SQL operations (Part 2), and a FastAPI web application with simple HTML pages (Part 3).

Team members, student IDs and contributions are in the executive summary.
The video link and the deployed application link are in `links.txt`.

---

## 1. Software versions

| Software | Version |
|---|---|
| PostgreSQL | 16 (tested with 16.14, official `postgres:16` Docker image) |
| Python | 3.12.3 |
| SQLAlchemy | 2.1.9 |
| psycopg2-binary | 2.9.13 |
| FastAPI | 0.165.0 |
| Starlette | 1.10.0 |
| Pydantic | 2.14.4 |
| Uvicorn | 0.54.0 |
| python-dotenv | 1.2.4 |

All Python packages are listed in `requirements.txt`. The web pages use plain HTML, CSS and
JavaScript (no extra libraries).

## 2. Project structure

```
db/
  schema.sql      creates all 15 tables with their constraints (drops them first, so it can be re-run)
  seed.sql        sample data
  view.sql        the view accepted_paper_schedule (task 8)
  dump.sql        pg_dump export: schema + data + view in one file
part2/
  db.py           database connection and a helper that runs a .sql file
  run_queries.py  Part 2: every task, numbered, with SQL and results
app/
  main.py         the web application, error messages
  checks.py       the two required application checks
  users.py  papers.py  reviews.py  sessions.py   create/read/update/delete endpoints
  lookups.py      read-only lists (conferences, tracks, reviewer pools)
  database.py     connection and small helpers
  static/         the HTML pages, JavaScript and CSS
requirements.txt
.env.example      example of the database connection setting
README.md
```

## 3. Database setup and restoration

The database is called `conference`. The default connection used by the code is
`postgresql+psycopg2://postgres:postgres@localhost:5432/conference`. To use another database, set the
environment variable `DATABASE_URL` or copy `.env.example` to `.env` and edit it.

### 3.1 Start PostgreSQL (Docker example)

```bash
docker run --name csci341-pg -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=conference -p 5432:5432 -d postgres:16
```

If port 5432 is already used by another PostgreSQL, use another port (for example `-p 5434:5432`) and set
`DATABASE_URL=postgresql+psycopg2://postgres:postgres@localhost:5434/conference` in `.env`.
Any other PostgreSQL 16 server also works.

### 3.2 Restore the database (choose one way)

**Way A: from the dump (one file, includes the view).**

```bash
psql -U postgres -d conference -f db/dump.sql
```

With Docker:

```bash
docker exec -i csci341-pg psql -U postgres -d conference < db/dump.sql
```

**Way B: from the source scripts.**

```bash
psql -U postgres -d conference -f db/schema.sql
psql -U postgres -d conference -f db/seed.sql
psql -U postgres -d conference -f db/view.sql
```

**Way C: let the Python program do it.** `python part2/run_queries.py` (section 4) runs `schema.sql` and
`seed.sql` itself, and creates the view at task 8.

### 3.3 Restore the original sample data at any time

Run Way A again (the dump starts with `DROP ... IF EXISTS`), or run `schema.sql` followed by
`seed.sql` and `view.sql`. `schema.sql` drops and recreates every table, so the result is always the
original data. Running `part2/run_queries.py` also resets the database.

## 4. Running the Part 2 queries

```bash
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python part2/run_queries.py
```

To save the output: `python part2/run_queries.py > part2/output.txt`

**Warning:** the program first runs `schema.sql` and `seed.sql`, so it replaces the contents of the
database it connects to.

The output is organized by task number (Task 1, Task 2, Task 3.1, ... Task 8). For every task it prints the
SQL text, the bound parameters, and the result. For updates and deletes it prints the data before and after
the change, then rolls the transaction back and prints the data again to show that the original seed data
is restored. Every independent change therefore runs against the original data.

All inputs are bound parameters (`:name` placeholders with `sqlalchemy.text()`). Filtering, joins,
aggregation and the nested query are done in the database.

## 5. Running the web application

```bash
source .venv/bin/activate          # Windows: .venv\Scripts\activate
uvicorn app.main:app --reload
```

The database must be restored first (section 3.2). Then open:

| Address | What it is |
|---|---|
| `http://127.0.0.1:8000/` | the web pages (Users, Papers, Reviews, Sessions) |
| `http://127.0.0.1:8000/docs` | interactive API documentation: every operation can be tried there |
| `http://127.0.0.1:8000/health` | answers `{"status":"ok"}` when the database is reachable |

**What the application does**

- Full create, read, update and delete for **users** (with author and reviewer profiles, research areas and
  expertise), **papers** (with authorship, keywords and versions), **reviews** and **sessions**.
- Conferences, tracks, reviewer pools and host institutions are read-only selection lists filled by the seed.
- Every change runs in one database transaction. If any part fails, nothing is saved.
- A rejected change shows a red message with the reason (HTTP status 409). Database rules
  (unique, CHECK, foreign keys) and the two application checks use the same kind of message.
- There is no login and there are no file uploads, as allowed by the assignment. Only a file location is
  stored for each paper version.

**Deployment.** The deployed address is in `links.txt`. The application needs two settings:
the start command `uvicorn app.main:app --host 0.0.0.0 --port $PORT` and the environment variable
`DATABASE_URL` of a persistent PostgreSQL database, restored from `db/dump.sql` (section 3.2).

## 6. Schema and keys

Primary keys are underlined in the reference schema; here they are listed as PK. `FK` means foreign key.
Names that differ from the reference schema are listed in section 10.

| Table | Primary key | Foreign keys (delete action) | Other constraints |
|---|---|---|---|
| `app_user` | `user_id` | | `email` UNIQUE, NOT NULL; `phone` NOT NULL |
| `author` | `author_id` | `author_id` -> `app_user` (CASCADE) | `orcid` UNIQUE, optional |
| `reviewer` | `reviewer_id` | `reviewer_id` -> `app_user` (CASCADE) | CHECK `years_experience >= 0` |
| `author_research_area` | (`author_id`, `area_label`) | `author_id` -> `author` (CASCADE) | |
| `reviewer_expertise` | (`reviewer_id`, `area_label`) | `reviewer_id` -> `reviewer` (CASCADE) | |
| `conference` | `conference_id` | | `description` NOT NULL; CHECK `end_date >= start_date` |
| `conference_host` | (`conference_id`, `host_name`) | `conference_id` -> `conference` (CASCADE) | |
| `conference_reviewer` | (`conference_id`, `reviewer_id`) | `conference_id` -> `conference` (CASCADE), `reviewer_id` -> `reviewer` (CASCADE) | the reviewer pool |
| `track` | `track_id` | `conference_id` -> `conference` (CASCADE), `coordinator_id` -> `reviewer` (RESTRICT) | UNIQUE (`conference_id`, `name`) |
| `conference_session` | `session_id` | `conference_id` -> `conference` (CASCADE), `chair_id` -> `reviewer` (RESTRICT) | CHECK `end_time > start_time` |
| `paper` | `paper_id` | `track_id` -> `track` (RESTRICT), `session_id` -> `conference_session` (SET NULL, optional) | CHECK status in (submitted, under review, accepted, rejected, withdrawn) |
| `paper_keyword` | (`paper_id`, `keyword`) | `paper_id` -> `paper` (CASCADE) | |
| `paper_author` | (`paper_id`, `author_id`) | `paper_id` -> `paper` (CASCADE), `author_id` -> `author` (RESTRICT) | UNIQUE (`paper_id`, `author_position`); CHECK `author_position > 0`; at most one corresponding author per paper (partial unique index) |
| `paper_version` | (`paper_id`, `version_no`) | `paper_id` -> `paper` (CASCADE) | CHECK `version_no > 0`; `change_note` optional |
| `review` | `review_id` | `paper_id` -> `paper` (CASCADE), `reviewer_id` -> `reviewer` (RESTRICT) | UNIQUE (`paper_id`, `reviewer_id`); CHECK `overall_score` 1 to 5; CHECK `recommendation` in (accept, reject); required columns NOT NULL (completed reviews only); `confidential_comments` optional |

Multivalued attributes (research areas, expertise, host institutions, keywords) are stored in separate
relations, not in comma-separated columns.

**Delete behaviour (choices made):**

- Deleting a **paper** removes its versions, authorship, keywords and reviews (CASCADE).
- Deleting a **session** keeps its papers; their `session_id` becomes NULL.
- Deleting a **conference** removes its tracks, sessions, host rows and reviewer-pool links, but never
  users, authors or reviewers. A conference whose tracks still have papers cannot be deleted (RESTRICT on
  `paper.track_id`).
- A **reviewer** with reviews, or who coordinates a track or chairs a session, cannot be deleted
  (RESTRICT). An **author** who is listed on a paper cannot be deleted (RESTRICT).
- Foreign keys are never disabled.

## 7. Required application checks

Both checks are in `app/checks.py` and are called from the web application. A broken rule rejects the
whole change (the transaction is rolled back) and the user sees the reason.

**Check 1: no self-reviews**

- `check_no_self_review`: called when a review is created and when a review is updated (paper or reviewer
  can change). Rejected if the reviewer is an author of that paper.
- `check_new_authors_did_not_review`: called when the author list of a paper changes. Rejected if one of
  the new authors has already reviewed that paper.

**Check 2: valid session assignments**

- `check_session_assignment`: called when a paper is created or updated, using the values the paper would
  have after the change. A paper with a session must have status `accepted`, and its track and its session
  must belong to the same conference. This covers a new assignment and also changes of status, track or
  session.
- `check_session_conference_change`: called when a session is updated. If its conference changes, none of
  its scheduled papers may belong to a different conference.

We chose to **reject** the invalid change, not to remove the assignment silently.

**How to demonstrate them (with the sample data)**

| Demonstration | Steps | Expected result |
|---|---|---|
| Self-review rejected | Reviews page: paper `#3`, reviewer `#5 Timur Bekov` (he wrote paper 3) | red message: Self-review rejected |
| Invalid session (other conference) | Sessions page, "Schedule a paper": paper `#9`, session `#1` | red message: conference mismatch |
| Invalid session (not accepted) | the same box: paper `#6` (only submitted), session `#1` | red message: only accepted papers |
| Valid assignment | the same box: paper `#4`, session `#2` | green message |

The same operations are available as API calls on `/docs` (`POST /reviews`, `PUT /papers/{id}`).
The sample data itself satisfies both rules.

## 8. Other business rules (optional enforcement)

All rules of Assignment 1 hold in the sample data. The table says whether the application also enforces
them.

| Rule | Enforced? | How |
|---|---|---|
| Every user is an author, a reviewer, or both | Yes, in the web application | creating or updating a user without either profile is rejected |
| Every author has at least one research-area label | No | every author in the seed has a label, and the application accepts an empty `research_areas` list |
| Every reviewer has at least one expertise-area label | No | every reviewer in the seed has a label, and the application accepts an empty `expertise` list |
| Every paper has at least one author | Yes, in the web application | checked when a paper is created or its authors are changed |
| Exactly one corresponding author per paper | Yes, in the web application | checked on create and on author changes; the database also forbids two |
| Every paper has at least one version | Yes, in the web application | required on create; the last version cannot be deleted |
| A paper has keywords | No | optional; the sample data has them |
| Every conference has at least one host and one reviewer in its pool | No | these tables are read-only in the application; the sample data satisfies it |
| Track coordinators and session chairs belong to the conference's reviewer pool | No | the composite foreign keys are optional; the sample data satisfies it (the application only checks that the chair is a reviewer) |
| A review is written by a reviewer from the paper's conference pool | No | the sample data satisfies it |
| Current version = highest version number | By design | not stored; computed as the highest `version_no` |

## 9. Design assumptions

- Version numbers may have gaps (the sample data has paper 1 with versions 1, 2, 4). The current version is
  the one with the highest number.
- Review scores and recommendations are rejected by the database CHECK constraints, not by the pages, so
  the same rule applies to every way of writing data.
- Reviews are stored only when complete: score, recommendation and comments for authors are NOT NULL.
  Only the confidential comments are optional.
- `paper.session_id` is NULL when a paper is not scheduled.
- A track must have a coordinator and a session must have a chair (both NOT NULL).
- The update operations for papers, reviews and sessions change only the fields that are sent. For a user,
  the full user is sent and the author and reviewer profiles are replaced as a whole.
- Removing an author or reviewer profile from a user is refused by the database while the user still has
  papers or reviews.

## 10. Changes compared with Assignment 1

The design follows the Assignment 1 model and the reference schema in Appendix A. Names that differ:

| Assignment 1 | This project | Reason |
|---|---|---|
| `USER` | `app_user` | `user` is a reserved word in SQL |
| `SESSION` | `conference_session` | avoids confusion with web sessions |
| `IN_POOL` | `conference_reviewer` | as in the reference schema |
| `date`, `room` (session) | `session_date`, `room_label` | clearer, avoids reserved word `date` |
| `version_number`, `upload_datetime` | `version_no`, `uploaded_at` | shorter names |
| `review_date` | `review_submission_date` | as in the reference schema |
| multivalued `expertise_area`, `research_area`, `host_institution`, `keyword` | tables `reviewer_expertise`, `author_research_area`, `conference_host`, `paper_keyword` | multivalued attributes in separate relations |
| `current_version` (derived) | not stored | computed as the highest `version_no` |

We kept the Assignment 1 names `name` and `phone` for users; the reference schema calls them `given_name`
and `phone_number`.

## 11. Query parameter values (Part 2)

The values used in `part2/run_queries.py`:

| Task | Parameter | Value |
|---|---|---|
| 3.1 | user email / new phone number | `arman.armanov@example.com` / `+77773414141` |
| 3.2 | city with +7 days (others get +3) | `Astana` |
| 4.1 | corresponding author email | `amina.aminova@example.com` |
| 4.2 | city | `Astana` |
| 5.2 | search pattern (case-insensitive) | `%machine learning%` |
| 5.3 | paper | paper ID `1` |
| 5.4 | conference / expertise / minimum years | conference ID `1` / `Databases` / `3` |

Expected results with the sample data include: task 4.1 deletes papers 12 and 13; task 4.2 deletes session 3;
task 5.4 returns reviewers 1, 5, 8 and 11; task 6.4 returns reviewers 1, 6, 7 and 11 (average 2.57 reviews
per reviewer, counting the reviewer with no reviews); task 7 gives 80.00 for ASDS 2026, 66.67 for BSSS 2026
and NULL for AWN 2026.
