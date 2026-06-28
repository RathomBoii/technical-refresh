from __future__ import annotations

from service.entity.user import User
from service.repository.ports import UserRepositoryPort


class GetUserByIdUseCase:
    """User action: look up a single user by their id."""

    def __init__(self, repo: UserRepositoryPort) -> None:
        self._repo = repo

    def execute(self, user_id: int) -> User | None:
        return self._repo.find_by_id(user_id)
