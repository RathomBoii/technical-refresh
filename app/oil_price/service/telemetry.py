from __future__ import annotations

import logging
import os

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import SERVICE_NAME, Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

logger = logging.getLogger(__name__)

_SERVICE_NAME = "oil-price-dashboard"


def setup_tracing() -> None:
    """Configure OpenTelemetry TracerProvider with OTLP gRPC export to Tempo.

    Reads OTEL_EXPORTER_OTLP_ENDPOINT from the environment.
    Format: host:port (e.g. "tempo.monitoring.svc.cluster.local:4317")
    If not set or empty, traces are collected but not exported (safe for local dev).
    """
    resource = Resource.create({SERVICE_NAME: _SERVICE_NAME})
    provider = TracerProvider(resource=resource)

    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "")
    if endpoint:
        # insecure=True: in-cluster communication without TLS
        exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
        provider.add_span_processor(BatchSpanProcessor(exporter))
        logger.info("OTel tracing → %s", endpoint)
    else:
        logger.info("OTEL_EXPORTER_OTLP_ENDPOINT not set — traces collected but not exported")

    trace.set_tracer_provider(provider)


def get_tracer(name: str = _SERVICE_NAME) -> trace.Tracer:
    """Return a named tracer for manual span creation in use-cases.

    Usage in a use-case:
        from service.telemetry import get_tracer
        _tracer = get_tracer(__name__)

        def execute(self):
            with _tracer.start_as_current_span("MyUseCase.execute") as span:
                span.set_attribute("key", "value")
                return self._repo.find_something()
    """
    return trace.get_tracer(name)
