from __future__ import annotations

from service.repository.ports import UserRepositoryPort


class DeleteUserUseCase:
    """User action: delete a user account by id."""

    def __init__(self, repo: UserRepositoryPort) -> None:
        self._repo = repo

    def execute(self, user_id: int) -> bool:
        return self._repo.delete(user_id)
