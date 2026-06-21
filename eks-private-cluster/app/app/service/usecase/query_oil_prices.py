from __future__ import annotations

from service.entity.oil_price import OilPrice
from service.repository.ports import OilPriceRepositoryPort
from service.telemetry import get_tracer

# Module-level tracer — created once, reused per request.
# This is the practice point: even in a single-service app, you can see
# the internal span tree: HTTP span → use-case span → psycopg2 SQL span.
_tracer = get_tracer(__name__)


class QueryOilPricesUseCase:
    """User action: query the latest price for every oil type."""

    def __init__(self, repo: OilPriceRepositoryPort) -> None:
        self._repo = repo

    def execute(self) -> list[OilPrice]:
        # Manual span: labels this use-case as a distinct step in the trace.
        # In Grafana → Tempo you will see:
        #   GET /oil/prices
        #     └─ QueryOilPricesUseCase.execute   ← this span
        #          └─ SELECT DISTINCT ON ...       ← psycopg2 auto-span
        with _tracer.start_as_current_span("QueryOilPricesUseCase.execute") as span:
            prices = self._repo.find_latest()
            # Attach a business-level attribute — visible in the Tempo span detail pane.
            span.set_attribute("oil_prices.count", len(prices))
            return prices

