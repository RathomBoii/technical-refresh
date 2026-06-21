from contextlib import asynccontextmanager
import logging

from fastapi import FastAPI
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor
from prometheus_fastapi_instrumentator import Instrumentator

from service.controller import health_controller, oil_price_controller, user_controller
from service.logging_config import setup_logging
from service.repository.connection import close_pool, get_pool, init_pool
from service.repository.postgres_oil_price_repository import PostgresOilPriceRepository
from service.telemetry import setup_tracing

# ── Observability bootstrap ─────────────────────────────────────────────────
# Must run before app creation so that all loggers and the tracer provider are
# configured before any FastAPI/uvicorn code references them.
setup_logging()
setup_tracing()

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ────────────────────────────────────────────────────────────
    logger.info("Startup: instrumenting psycopg2 for OTel tracing")
    # Auto-creates a child span for every SQL query — visible in Tempo traces.
    Psycopg2Instrumentor().instrument()

    logger.info("Startup: initialising DB connection pool")
    init_pool()
    pool = get_pool()
    conn = pool.getconn()
    try:
        repo = PostgresOilPriceRepository(conn)
        repo.init_schema()
        repo.seed_prices()
    finally:
        pool.putconn(conn)

    logger.info("Startup complete — oil price dashboard is ready")
    yield

    # ── Shutdown ───────────────────────────────────────────────────────────
    logger.info("Shutdown: closing DB connection pool")
    close_pool()


# ── FastAPI app ─────────────────────────────────────────────────────────────
app = FastAPI(
    title="Oil Price Dashboard",
    version="2.0.0",
    description="World oil pricing dashboard with user management — verifies EKS→RDS private connectivity.",
    lifespan=lifespan,
)

# ── Phase 3: OTel tracing — auto-instrument every FastAPI route ─────────────
# Creates a root span per HTTP request with method, route, status code attributes.
FastAPIInstrumentor.instrument_app(app)

# ── Phase 1: Prometheus metrics — expose /metrics scrape endpoint ───────────
# Instruments all routes: http_request_duration_seconds (histogram),
# http_requests_total (counter), http_requests_in_progress (gauge).
Instrumentator().instrument(app).expose(app)

app.include_router(health_controller.router)
app.include_router(user_controller.router)
app.include_router(oil_price_controller.router)





