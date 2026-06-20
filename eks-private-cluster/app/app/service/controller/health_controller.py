from __future__ import annotations

import os
from typing import Any

from fastapi import APIRouter, Depends, HTTPException

from service.repository.connection import get_conn
from service.repository.postgres_oil_price_repository import PostgresOilPriceRepository
from service.usecase.check_database_health import CheckDatabaseHealthUseCase

router = APIRouter(tags=["health"])

API_KEY = os.environ.get("API_KEY")


@router.get("/")
def root():
    return {"service": "Oil Price Dashboard", "version": "2.0.0"}


@router.get("/health")
def health():
    return {"status": "healthy"}


@router.get("/db-check")
def db_check(conn: Any = Depends(get_conn)):
    try:
        result = CheckDatabaseHealthUseCase(conn).execute()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Database unreachable: {exc}") from exc
    return result


@router.get("/secret-check")
def secret_check():
    """Confirms whether the API_KEY secret was injected — never exposes the value."""
    return {"api_key_loaded": API_KEY is not None}
