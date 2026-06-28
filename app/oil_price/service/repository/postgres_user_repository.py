from __future__ import annotations

from typing import Any

from service.entity.user import User
from service.repository.ports import UserRepositoryPort
from service.repository.transaction import TransactionManager


class PostgresUserRepository(UserRepositoryPort):
    """Outbound adapter — persists and retrieves User entities via PostgreSQL."""

    def __init__(self, conn: Any) -> None:
        self._conn = conn

    # ------------------------------------------------------------------
    # Writes — wrapped in TransactionManager
    # ------------------------------------------------------------------

    def save(self, user: User) -> User:
        with TransactionManager(self._conn) as cur:
            cur.execute(
                """
                INSERT INTO users (username, email, full_name)
                VALUES (%s, %s, %s)
                RETURNING id, created_at
                """,
                (user.username, user.email, user.full_name),
            )
            row = cur.fetchone()

        user.id = row[0]
        user.created_at = row[1]
        return user

    def delete(self, user_id: int) -> bool:
        with TransactionManager(self._conn) as cur:
            cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
            return cur.rowcount > 0

    # ------------------------------------------------------------------
    # Reads — autocommit-safe, no explicit transaction needed
    # ------------------------------------------------------------------

    def find_all(self) -> list[User]:
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT id, username, email, full_name, created_at FROM users ORDER BY id"
            )
            rows = cur.fetchall()
        return [
            User.from_row(
                {"id": r[0], "username": r[1], "email": r[2], "full_name": r[3], "created_at": r[4]}
            )
            for r in rows
        ]

    def find_by_id(self, user_id: int) -> User | None:
        with self._conn.cursor() as cur:
            cur.execute(
                "SELECT id, username, email, full_name, created_at FROM users WHERE id = %s",
                (user_id,),
            )
            row = cur.fetchone()
        if row is None:
            return None
        return User.from_row(
            {"id": row[0], "username": row[1], "email": row[2], "full_name": row[3], "created_at": row[4]}
        )
