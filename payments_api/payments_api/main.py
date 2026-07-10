"""Entry point for the payment-api application."""

from fastapi import FastAPI
from prometheus_client import Gauge
from prometheus_fastapi_instrumentator import Instrumentator

from payments_api.routers import health, payments

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

# Exposes /metrics with HTTP request counters, latency histograms and
# in-progress gauges (labeled by method, handler and status), in addition
# to the custom gauges registered above.
Instrumentator().instrument(app).expose(app, include_in_schema=False)

app.include_router(health.router)
app.include_router(payments.router)
