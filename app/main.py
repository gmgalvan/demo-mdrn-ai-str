"""Entry point for the payment-api application."""

from fastapi import FastAPI
from prometheus_client import CONTENT_TYPE_LATEST, Gauge, generate_latest
from starlette.responses import Response

from app.routers import health, payments

app = FastAPI(
    title="payment-api",
    description="Payments microservice for the AI-applied-to-DevOps demo.",
    version="1.0.0",
)


APP_INFO = Gauge(
    "payment_api_info",
    "Static application information for payment-api.",
    ["service", "version"],
)
APP_INFO.labels(service="payment-api", version=app.version).set(1)


@app.get("/metrics", include_in_schema=False)
def metrics() -> Response:
    """Expose Prometheus metrics."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


app.include_router(health.router)
app.include_router(payments.router)
