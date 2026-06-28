from __future__ import annotations

import random
from datetime import datetime
from typing import Any


BASE_PRICES: dict[str, float] = {
    "WTI_CRUDE":    78.50,
    "BRENT_CRUDE":  82.30,
    "OPEC_BASKET":  80.10,
    "NATURAL_GAS":   2.85,
    "HEATING_OIL":   2.65,
}


class OilPrice:
    """OilPrice domain entity.

    Encapsulates price simulation logic. No framework or DB imports allowed here.
    """

    def __init__(
        self,
        id: int | None,
        oil_type: str,
        price_usd: float,
        change_pct: float,
        recorded_at: datetime,
    ) -> None:
        self.id = id
        self.oil_type = oil_type
        self.price_usd = price_usd
        self.change_pct = change_pct
        self.recorded_at = recorded_at

    # ------------------------------------------------------------------
    # Factory — generate a simulated price point
    # ------------------------------------------------------------------

    @classmethod
    def generate(cls, oil_type: str, base_price: float, recorded_at: datetime) -> "OilPrice":
        """Simulate a price point with a random ±3 % variation around base_price."""
        if oil_type not in BASE_PRICES:
            raise ValueError(f"unknown oil_type '{oil_type}'; valid types: {list(BASE_PRICES)}")

        change_pct = round(random.uniform(-3.0, 3.0), 4)
        price_usd = round(base_price * (1 + change_pct / 100), 4)

        return cls(
            id=None,
            oil_type=oil_type,
            price_usd=price_usd,
            change_pct=change_pct,
            recorded_at=recorded_at,
        )

    # ------------------------------------------------------------------
    # Rehydration — reconstruct from a DB row dict
    # ------------------------------------------------------------------

    @classmethod
    def from_row(cls, row: dict[str, Any]) -> "OilPrice":
        return cls(
            id=row["id"],
            oil_type=row["oil_type"],
            price_usd=float(row["price_usd"]),
            change_pct=float(row["change_pct"]),
            recorded_at=row["recorded_at"],
        )

    # ------------------------------------------------------------------
    # Serialisation — plain dict for API responses
    # ------------------------------------------------------------------

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "oil_type": self.oil_type,
            "price_usd": self.price_usd,
            "change_pct": self.change_pct,
            "recorded_at": self.recorded_at.isoformat() if self.recorded_at else None,
        }
