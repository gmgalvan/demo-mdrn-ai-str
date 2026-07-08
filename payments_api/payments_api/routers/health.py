"""Health check router for payment-api."""

from fastapi import APIRouter

router = APIRouter(tags=["health"])

# NOTE: /health/detailed is intentionally NOT implemented here.
# It will be generated live by the agent during Demo 1.


@router.get("/health")
def get_health() -> dict[str, str]:
    """Return the basic service status.

    Returns:
        Dictionary with the service status.
    """
    return {"status": "ok"}
