from __future__ import annotations

import logging
import sys
from typing import Any

from opentelemetry import trace
from pythonjsonlogger import jsonlogger


class _TraceIdJsonFormatter(jsonlogger.JsonFormatter):
    """JSON log formatter that injects the active OTel trace_id and span_id.

    Every log line will be a single JSON object like:
        {"message": "...", "level": "INFO", "logger": "service.usecase.query_oil_prices",
         "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736", "span_id": "00f067aa0ba902b7"}

    This enables trace↔log correlation in Grafana:
    Loki query by trace_id → jump to the exact Tempo trace.
    """

    def add_fields(
        self,
        log_record: dict[str, Any],
        record: logging.LogRecord,
        message_dict: dict[str, Any],
    ) -> None:
        super().add_fields(log_record, record, message_dict)

        # Inject current OTel trace context if a span is active
        span = trace.get_current_span()
        ctx = span.get_span_context()
        if ctx.is_valid:
            log_record["trace_id"] = format(ctx.trace_id, "032x")
            log_record["span_id"] = format(ctx.span_id, "016x")

        log_record["level"] = record.levelname
        log_record["logger"] = record.name


def setup_logging(level: int = logging.INFO) -> None:
    """Replace root logger handlers with a structured JSON stdout handler.

    Call this once at process startup (before FastAPI app creation) so that
    uvicorn and all app loggers emit JSON. The trace_id field is injected
    automatically when a request span is active.
    """
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(_TraceIdJsonFormatter("%(message)s"))

    root = logging.getLogger()
    root.setLevel(level)
    # Remove any pre-existing handlers (uvicorn default handlers, etc.)
    root.handlers = [handler]
