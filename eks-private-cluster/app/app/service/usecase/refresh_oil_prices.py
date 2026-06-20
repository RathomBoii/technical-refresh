from __future__ import annotations

from datetime import datetime, timezone

from service.entity.oil_price import BASE_PRICES, OilPrice
from service.repository.ports import OilPriceRepositoryPort


class RefreshOilPricesUseCase:
    """User action: generate and persist a fresh price snapshot for all oil types."""

    def __init__(self, repo: OilPriceRepositoryPort) -> None:
        self._repo = repo

    def execute(self) -> list[OilPrice]:
        now = datetime.now(tz=timezone.utc)
        prices = [
            OilPrice.generate(oil_type, base_price, now)
            for oil_type, base_price in BASE_PRICES.items()
        ]
        self._repo.save_prices(prices)
        return prices
