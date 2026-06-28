from __future__ import annotations

from service.entity.user import User
from service.repository.ports import UserRepositoryPort


class RegisterUserUseCase:
    """User action: register a new user account."""

    def __init__(self, repo: UserRepositoryPort) -> None:
        self._repo = repo

    def execute(self, username: str, email: str, full_name: str) -> User:
        user = User.create(username, email, full_name)
        return self._repo.save(user)
