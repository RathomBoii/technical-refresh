from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from service.entity.oil_price import BASE_PRICES, OilPrice
from service.repository.ports import OilPriceRepositoryPort
from service.repository.transaction import TransactionManager


class PostgresOilPriceRepository(OilPriceRepositoryPort):
    """Outbound adapter — persists and retrieves OilPrice entities via PostgreSQL."""

    def __init__(self, conn: Any) -> None:
        self._conn = conn

    # ------------------------------------------------------------------
    # Schema management (called once at startup)
    # ------------------------------------------------------------------

    def init_schema(self) -> None:
        with TransactionManager(self._conn) as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    id         SERIAL PRIMARY KEY,
                    username   VARCHAR(64)  NOT NULL UNIQUE,
                    email      VARCHAR(255) NOT NULL UNIQUE,
                    full_name  VARCHAR(255) NOT NULL,
                    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS oil_prices (
                    id          SERIAL PRIMARY KEY,
                    oil_type    VARCHAR(32)    NOT NULL,
                    price_usd   NUMERIC(10, 4) NOT NULL,
                    change_pct  NUMERIC(7, 4)  NOT NULL,
                    recorded_at TIMESTAMPTZ    NOT NULL DEFAULT NOW()
                )
                """
            )
            cur.execute(
                "CREATE INDEX IF NOT EXISTS idx_oil_prices_type_time ON oil_prices (oil_type, recorded_at DESC)"
            )

    def seed_prices(self) -> None:
        """Insert 7 days × 24 hours of simulated prices for every oil type.

        Idempotent — skips seeding if rows already exist.
        """
        with self._conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM oil_prices")
            count = cur.fetchone()[0]

        if count > 0:
            return  # already seeded

        now = datetime.now(tz=timezone.utc)
        prices: list[OilPrice] = []

        for hours_ago in range(7 * 24, 0, -1):
            recorded_at = now - timedelta(hours=hours_ago)
            for oil_type, base_price in BASE_PRICES.items():
                prices.append(OilPrice.generate(oil_type, base_price, recorded_at))

        self.save_prices(prices)

    # ------------------------------------------------------------------
    # Writes
    # ------------------------------------------------------------------

    def save_prices(self, prices: list[OilPrice]) -> None:
        with TransactionManager(self._conn) as cur:
            cur.executemany(
                """
                INSERT INTO oil_prices (oil_type, price_usd, change_pct, recorded_at)
                VALUES (%s, %s, %s, %s)
                """,
                [(p.oil_type, p.price_usd, p.change_pct, p.recorded_at) for p in prices],
            )

    # ------------------------------------------------------------------
    # Reads
    # ------------------------------------------------------------------

    def find_latest(self) -> list[OilPrice]:
        """Return the single most-recent price row for each oil type."""
        with self._conn.cursor() as cur:
            cur.execute(
                """
                SELECT DISTINCT ON (oil_type)
                    id, oil_type, price_usd, change_pct, recorded_at
                FROM oil_prices
                ORDER BY oil_type, recorded_at DESC
                """
            )
            rows = cur.fetchall()
        return [self._row_to_entity(r) for r in rows]

    def find_history(self, oil_type: str, hours: int) -> list[OilPrice]:
        """Return price history for the given oil_type over the last `hours` hours."""
        with self._conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, oil_type, price_usd, change_pct, recorded_at
                FROM oil_prices
                WHERE oil_type = %s
                  AND recorded_at > NOW() - (%s * INTERVAL '1 hour')
                ORDER BY recorded_at ASC
                """,
                (oil_type, hours),
            )
            rows = cur.fetchall()
        return [self._row_to_entity(r) for r in rows]

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _row_to_entity(row: tuple) -> OilPrice:
        return OilPrice.from_row(
            {
                "id": row[0],
                "oil_type": row[1],
                "price_usd": row[2],
                "change_pct": row[3],
                "recorded_at": row[4],
            }
        )
