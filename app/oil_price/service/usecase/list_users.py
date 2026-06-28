from __future__ import annotations

from service.entity.user import User
from service.repository.ports import UserRepositoryPort


class ListUsersUseCase:
    """User action: list all registered users."""

    def __init__(self, repo: UserRepositoryPort) -> None:
        self._repo = repo

    def execute(self) -> list[User]:
        return self._repo.find_all()
