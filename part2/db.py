import os
from pathlib import Path

from dotenv import load_dotenv
from sqlalchemy import create_engine

# Read DATABASE_URL from the .env file if there is one.
load_dotenv()

# Without DATABASE_URL, use a local PostgreSQL on the standard port 5432.
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/conference",
)

engine = create_engine(DATABASE_URL)


def run_sql_file(path):
    """Print and execute the SQL script as one batch."""
    sql = Path(path).read_text(encoding="utf-8")
    print("\n" + sql.strip())

    raw = engine.raw_connection()
    try:
        cursor = raw.cursor()
        cursor.execute(sql)
        cursor.close()
        raw.commit()
    finally:
        raw.close()
