# Payments Service — Possible Next Steps

Ideas for extending [payments_api/payments_api/routers/payments.py](../payments_api/payments_api/routers/payments.py)
beyond the current `GET /payments` / `POST /payments`. Not committed work,
just a backlog to pick from.

## Basic CRUD gaps

- `GET /payments/{id}` — fetch a single payment, 404 if it doesn't exist.
- `PATCH /payments/{id}/status` — status transition
  (`pending` -> `completed` / `failed` / `refunded`).
- `DELETE /payments/{id}` — cancel a payment (soft-delete, not a hard
  delete, to keep the demo data consistent).

## Filtering and pagination

- `GET /payments?status=pending&currency=USD`
- Simple `limit`/`offset` pagination.

Useful to generate more varied traffic for the observability demo.

## Deliberate failure cases

Good for practicing diagnosis with Claude Code:

- Validate `currency` against a real ISO 4217 list (today it only checks
  length == 3).
- An endpoint that simulates latency or fails randomly, to trigger alerts
  in Grafana/Prometheus.

## Business metrics

The service already exposes `/metrics` via `prometheus-client`
([payments_api/payments_api/main.py](../payments_api/payments_api/main.py)). A payments counter broken down by
`status`/`currency` would be more interesting for dashboards than the
current static `payment_api_info` gauge.

## Explicitly out of scope

Auth, a real database, webhooks, and other production-grade payment
concerns are intentionally left out. The purpose of this repo is the
AI-applied-to-DevOps demo (see [README.md](../README.md)), not a
production payments service — adding domain complexity here would dilute
that focus.
