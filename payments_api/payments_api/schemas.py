"""Pydantic models shared across payment-api routers."""

from pydantic import BaseModel, Field


class PaymentCreate(BaseModel):
    """Data required to create a payment."""

    amount: float = Field(..., gt=0, description="Payment amount, must be greater than zero")
    currency: str = Field(..., min_length=3, max_length=3, description="ISO 4217 code, e.g. MXN")
    description: str = Field(default="", description="Optional payment description")


class Payment(PaymentCreate):
    """Full representation of a stored payment."""

    id: int = Field(..., description="Unique payment identifier")
    status: str = Field(default="pending", description="Current payment status")
