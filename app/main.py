"""Entry point for the payment-api application."""

from fastapi import FastAPI

from app.routers import health, payments

app = FastAPI(
    title="payment-api",
    description="Payments microservice for the AI-applied-to-DevOps demo.",
    version="1.0.0",
)

app.include_router(health.router)
app.include_router(payments.router)
