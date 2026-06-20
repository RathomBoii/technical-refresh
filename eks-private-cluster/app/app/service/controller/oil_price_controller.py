from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query

from service.entity.oil_price import BASE_PRICES
from service.repository.connection import get_conn
from service.repository.postgres_oil_price_repository import PostgresOilPriceRepository
from service.usecase.query_oil_price_history import QueryOilPriceHistoryUseCase
from service.usecase.query_oil_prices import QueryOilPricesUseCase
from service.usecase.refresh_oil_prices import RefreshOilPricesUseCase

router = APIRouter(prefix="/oil", tags=["oil prices"])

_VALID_OIL_TYPES = list(BASE_PRICES.keys())


@router.get("/prices")
def get_latest_prices(conn: Any = Depends(get_conn)):
    """Return the most-recent price snapshot for every oil type."""
    prices = QueryOilPricesUseCase(PostgresOilPriceRepository(conn)).execute()
    return [p.to_dict() for p in prices]


@router.get("/prices/history")
def get_price_history(
    oil_type: str = Query(..., description=f"One of: {_VALID_OIL_TYPES}"),
    hours: int = Query(24, ge=1, le=168, description="Look-back window in hours (1–168)"),
    conn: Any = Depends(get_conn),
):
    """Return historical price rows for the specified oil type."""
    if oil_type not in _VALID_OIL_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown oil_type '{oil_type}'. Valid values: {_VALID_OIL_TYPES}",
        )
    try:
        prices = QueryOilPriceHistoryUseCase(PostgresOilPriceRepository(conn)).execute(oil_type, hours)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return [p.to_dict() for p in prices]


@router.post("/prices/refresh", status_code=201)
def refresh_prices(conn: Any = Depends(get_conn)):
    """Generate and persist a fresh price snapshot for all oil types."""
    prices = RefreshOilPricesUseCase(PostgresOilPriceRepository(conn)).execute()
    return [p.to_dict() for p in prices]
