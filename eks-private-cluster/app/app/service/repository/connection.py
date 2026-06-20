from __future__ import annotations

import os
from typing import Generator

import psycopg2
import psycopg2.pool

_pool: psycopg2.pool.SimpleConnectionPool | None = None


def init_pool() -> None:
    """Initialise the global connection pool. Called once on application startup."""
    global _pool
    _pool = psycopg2.pool.SimpleConnectionPool(
        minconn=1,
        maxconn=10,
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", "5432")),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
    )


def get_pool() -> psycopg2.pool.SimpleConnectionPool:
    if _pool is None:
        raise RuntimeError("Connection pool is not initialised. Call init_pool() at startup.")
    return _pool


def close_pool() -> None:
    """Return all connections and close the pool. Called once on application shutdown."""
    global _pool
    if _pool is not None:
        _pool.closeall()
        _pool = None


def get_conn() -> Generator:
    """FastAPI Depends-compatible dependency that acquires and releases a connection."""
    pool = get_pool()
    conn = pool.getconn()
    try:
        yield conn
    finally:
        pool.putconn(conn)
