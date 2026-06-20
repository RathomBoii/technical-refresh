from __future__ import annotations

from service.entity.oil_price import OilPrice
from service.repository.ports import OilPriceRepositoryPort


class QueryOilPricesUseCase:
    """User action: query the latest price for every oil type."""

    def __init__(self, repo: OilPriceRepositoryPort) -> None:
        self._repo = repo

    def execute(self) -> list[OilPrice]:
        return self._repo.find_latest()
