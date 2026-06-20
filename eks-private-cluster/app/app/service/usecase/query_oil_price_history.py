from __future__ import annotations

from service.entity.oil_price import OilPrice
from service.repository.ports import OilPriceRepositoryPort


class QueryOilPriceHistoryUseCase:
    """User action: query historical prices for a specific oil type."""

    def __init__(self, repo: OilPriceRepositoryPort) -> None:
        self._repo = repo

    def execute(self, oil_type: str, hours: int) -> list[OilPrice]:
        if hours < 1 or hours > 168:
            raise ValueError("hours must be between 1 and 168 (7 days)")
        return self._repo.find_history(oil_type, hours)
