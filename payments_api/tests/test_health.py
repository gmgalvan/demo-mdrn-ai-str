"""Tests for the health check router."""

from fastapi.testclient import TestClient

from payments_api.main import app

client = TestClient(app)


def test_health_returns_200() -> None:
    """GET /health must respond with 200."""
    response = client.get("/health")
    assert response.status_code == 200


def test_health_returns_status_ok() -> None:
    """GET /health must return status ok."""
    response = client.get("/health")
    assert response.json() == {"status": "bien"}


def test_metrics_endpoint_exposes_prometheus_metrics() -> None:
    """GET /metrics must expose Prometheus metrics."""
    client.get("/health")
    response = client.get("/metrics")

    assert response.status_code == 200
    assert "payment_api_info" in response.text
