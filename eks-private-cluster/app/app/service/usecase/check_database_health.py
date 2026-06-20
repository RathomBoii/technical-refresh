from __future__ import annotations

from typing import Any


class CheckDatabaseHealthUseCase:
    """User action: verify EKS-to-RDS connectivity and return DB metadata."""

    def __init__(self, conn: Any) -> None:
        self._conn = conn

    def execute(self) -> dict:
        with self._conn.cursor() as cur:
            cur.execute("SELECT version(), inet_server_addr(), inet_server_port()")
            row = cur.fetchone()

        return {
            "status": "connected",
            "db_version": row[0],
            "db_host": str(row[1]) if row[1] else "n/a",
            "db_port": row[2],
        }
