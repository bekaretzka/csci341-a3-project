"""Database connection and small helpers shared by all endpoints."""

import os
from pathlib import Path

from dotenv import load_dotenv
from fastapi import HTTPException
from sqlalchemy import create_engine, text

# Read DATABASE_URL from the .env file (project root) if there is one.
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:postgres@localhost:5432/conference",
)

# Hosting providers give URLs that start with postgres:// or postgresql://.
# SQLAlchemy needs the driver name in it, so we add it.
if DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg2://", 1)
elif DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)


def to_dicts(result):
    """Turn query result rows into a list of dictionaries (easy to send as JSON)."""
    return [dict(row) for row in result.mappings()]


def get_one(conn, sql, params, not_found_message):
    """Run a query that should return one row. Answer 404 if there is none."""
    row = conn.execute(text(sql), params).mappings().first()
    if row is None:
        raise HTTPException(status_code=404, detail=not_found_message)
    return dict(row)


def insert_many(conn, sql, list_of_params):
    """Run the same INSERT for every item in the list (does nothing for an empty list)."""
    if list_of_params:
        conn.execute(text(sql), list_of_params)


def provided_fields(data, allowed):
    """
    For update requests: return only the fields the client actually sent.
    This lets the client send "session_id": null to clear a value,
    and leave a field out to keep it unchanged.
    """
    return {name: getattr(data, name) for name in data.model_fields_set if name in allowed}


def update_row(conn, table, key_column, key_value, changes):
    """
    UPDATE one row with the given {column: new value} changes.
    The table and column names come from our own code (a fixed list), never from
    the user, so building the SQL text this way is safe. Values are bound parameters.
    """
    if not changes:
        return
    set_clause = ", ".join(f"{column} = :{column}" for column in changes)
    conn.execute(
        text(f"UPDATE {table} SET {set_clause} WHERE {key_column} = :key_value"),
        {**changes, "key_value": key_value},
    )
