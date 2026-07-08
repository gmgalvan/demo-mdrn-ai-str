"""Tests for the payments router."""

from fastapi.testclient import TestClient

from payments_api.main import app

client = TestClient(app)


def test_list_payments_returns_200() -> None:
    """GET /payments must respond with 200."""
    response = client.get("/payments")
    assert response.status_code == 200


def test_list_payments_returns_list() -> None:
    """GET /payments must return a list with the mock payments."""
    response = client.get("/payments")
    body = response.json()
    assert isinstance(body, list)
    assert len(body) >= 2
    assert all("id" in p and "amount" in p and "currency" in p for p in body)


def test_create_payment_returns_201() -> None:
    """POST /payments must create a payment and respond with 201."""
    payload = {"amount": 99.90, "currency": "MXN", "description": "Test payment"}
    response = client.post("/payments", json=payload)
    assert response.status_code == 201
    body = response.json()
    assert body["amount"] == payload["amount"]
    assert body["currency"] == payload["currency"]
    assert body["status"] == "pending"
    assert isinstance(body["id"], int)


def test_created_payment_appears_in_list() -> None:
    """A created payment must appear in the payments list."""
    payload = {"amount": 10.50, "currency": "USD", "description": "Listed payment"}
    created = client.post("/payments", json=payload).json()
    listed = client.get("/payments").json()
    assert any(p["id"] == created["id"] for p in listed)


def test_create_payment_rejects_invalid_amount() -> None:
    """POST /payments must reject amounts less than or equal to zero."""
    payload = {"amount": -5, "currency": "MXN", "description": "Invalid amount"}
    response = client.post("/payments", json=payload)
    assert response.status_code == 422
