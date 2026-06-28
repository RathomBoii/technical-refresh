from __future__ import annotations

from types import TracebackType
from typing import Any


class TransactionManager:
    """Context manager that wraps a psycopg2 connection in a transaction.

    Commits on clean exit. Rolls back on any exception.
    Does NOT close the connection — the pool owns the connection lifecycle.

    Usage::

        with TransactionManager(conn) as cursor:
            cursor.execute("INSERT INTO ...", [...])
    """

    def __init__(self, conn: Any) -> None:
        self._conn = conn
        self._cursor: Any = None

    def __enter__(self) -> Any:
        self._cursor = self._conn.cursor()
        return self._cursor

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> bool:
        if exc_type is None:
            self._conn.commit()
        else:
            self._conn.rollback()
        self._cursor.close()
        return False  # do not suppress exceptions
