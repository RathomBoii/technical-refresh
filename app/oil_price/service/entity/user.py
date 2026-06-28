from __future__ import annotations

import re
from datetime import datetime
from typing import Any


class User:
    """User domain entity.

    Business rules are enforced in `create()`. No framework or DB imports allowed here.
    """

    def __init__(
        self,
        id: int | None,
        username: str,
        email: str,
        full_name: str,
        created_at: datetime | None,
    ) -> None:
        self.id = id
        self.username = username
        self.email = email
        self.full_name = full_name
        self.created_at = created_at

    # ------------------------------------------------------------------
    # Factory — enforces business invariants
    # ------------------------------------------------------------------

    @classmethod
    def create(cls, username: str, email: str, full_name: str) -> "User":
        """Validate inputs and return a new (unsaved) User entity.

        Raises ValueError if any business rule is violated.
        """
        username = username.strip()
        email = email.strip().lower()
        full_name = full_name.strip()

        if not username or len(username) < 3:
            raise ValueError("username must be at least 3 characters")
        if not re.match(r"^[a-z0-9_.-]+$", username):
            raise ValueError("username may only contain letters, digits, underscores, dots, or hyphens")
        if not email or "@" not in email:
            raise ValueError("email must be a valid email address")
        if not full_name:
            raise ValueError("full_name is required")

        return cls(id=None, username=username, email=email, full_name=full_name, created_at=None)

    # ------------------------------------------------------------------
    # Rehydration — reconstruct entity from a DB row dict
    # ------------------------------------------------------------------

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "User":
        return cls(
            id=row["id"],
            username=row["username"],
            email=row["email"],
            full_name=row["full_name"],
            created_at=row["created_at"],
        )

    # ------------------------------------------------------------------
    # Serialisation — plain dict for API responses
    # ------------------------------------------------------------------

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "username": self.username,
            "email": self.email,
            "full_name": self.full_name,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }
