from contextlib import asynccontextmanager
import asyncio
import logging
import random

from fastapi import FastAPI # pyright: ignore[reportMissingImports]
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor # pyright: ignore[reportMissingImports]
from opentelemetry.instrumentation.psycopg2 import Psycopg2Instrumentor # pyright: ignore[reportMissingImports]
from prometheus_fastapi_instrumentator import Instrumentator # pyright: ignore[reportMissingImports]

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

_RANDOM_LOG_MESSAGES = [
    "System heartbeat check passed [for testing only]",
    "Background worker is alive [for testing only]",
    "Memory usage within acceptable range [for testing only]",
    "Cache hit ratio looks healthy [for testing only]",
    "All downstream services reachable [for testing only]",
]

_random_log_task: asyncio.Task | None = None


async def _emit_random_log_every_10_minutes() -> None:
    while True:
        await asyncio.sleep(600)  # 10 minutes
        message = random.choice(_RANDOM_LOG_MESSAGES)
        logger.info(message)


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
    _random_log_task = asyncio.create_task(_emit_random_log_every_10_minutes())
    yield

    # ── Shutdown ───────────────────────────────────────────────────────────
    logger.info("Shutdown: closing DB connection pool")
    if _random_log_task:
        _random_log_task.cancel()
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





