"""Payments router for payment-api.

Payments are stored in memory: this service is a demo and does not
require a real database.
"""

from fastapi import APIRouter

from payments_api.schemas import Payment, PaymentCreate

router = APIRouter(prefix="/payments", tags=["payments"])

# In-memory store; reset on every process restart (fine for the demo).
_payments: list[Payment] = [
    Payment(id=1, amount=150.00, currency="MXN", description="Monthly subscription", status="completed"),
    Payment(id=2, amount=49.99, currency="USD", description="One-time purchase", status="pending"),
]


@router.get("", response_model=list[Payment])
def list_payments() -> list[Payment]:
    """Return the list of registered payments.

    Returns:
        List of in-memory payments.
    """
    return _payments


@router.post("", response_model=Payment, status_code=201)
def create_payment(payment: PaymentCreate) -> Payment:
    """Create a new payment in memory.

    Args:
        payment: Data of the payment to create.

    Returns:
        The created payment with its assigned identifier.
    """
    new_id = max((p.id for p in _payments), default=0) + 1
    new_payment = Payment(id=new_id, **payment.model_dump())
    _payments.append(new_payment)
    return new_payment
