from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI

from service.controller import health_controller, oil_price_controller, user_controller
from service.repository.connection import close_pool, get_pool, init_pool
from service.repository.postgres_oil_price_repository import PostgresOilPriceRepository


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: initialise DB pool, create schema, seed initial data
    init_pool()
    pool = get_pool()
    conn = pool.getconn()
    try:
        repo = PostgresOilPriceRepository(conn)
        repo.init_schema()
        repo.seed_prices()
    finally:
        pool.putconn(conn)

    yield

    # Shutdown: drain the pool
    close_pool()


app = FastAPI(
    title="Oil Price Dashboard",
    version="2.0.0",
    description="World oil pricing dashboard with user management — verifies EKS→RDS private connectivity.",
    lifespan=lifespan,
)

app.include_router(health_controller.router)
app.include_router(user_controller.router)
app.include_router(oil_price_controller.router)




