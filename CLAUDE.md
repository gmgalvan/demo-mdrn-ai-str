# payment-api — Project conventions

Payments microservice in Python/FastAPI used for AI-applied-to-DevOps demos.

## Structure

`payments_api/` is self-contained: its own `pyproject.toml`,
`requirements*.txt`, `uv.lock`, `Dockerfile` and `tests/` all live inside it,
so every Python command (`uv venv`, `uv run pytest`, `uv run uvicorn`, `docker
build`) runs from within `payments_api/`, never from the repo root.

- `payments_api/payments_api/main.py`: entry point, registers the routers.
- `payments_api/payments_api/routers/`: one file per domain (`health.py`, `payments.py`).
- `payments_api/payments_api/schemas.py`: shared Pydantic models.
- `payments_api/tests/`: one test file per router (`test_health.py`, `test_payments.py`).
- `k8s/`: Kubernetes manifests (namespace `demo`).
- `k8s/observability/`: Prometheus, Grafana, Loki and Promtail manifests
  (namespace `observability`).
- `.claude/mcp/.mcp.json`: tracked reference copy of the project's MCP
  server config. The file Claude Code actually loads is `.mcp.json` at the
  repo root, which is gitignored (local-only) — keep both in sync by hand
  when adding or changing an MCP server.

## Observability

- `payment-api` exposes Prometheus metrics on `/metrics` via
  `prometheus-fastapi-instrumentator` (HTTP request count, latency
  histogram, in-progress requests, all labeled by `handler`/`method`/`status`)
  plus any custom gauges registered in `main.py` (e.g. `payment_api_info`).
  Prometheus scrapes it via the static `payment-api` job in
  `k8s/observability/prometheus.yaml`.
- `webui` (nginx) has no application code to instrument; it exposes nginx's
  built-in `stub_status` (see `webui/nginx.conf.template`), read by an
  `nginx-prometheus-exporter` sidecar (see `k8s/webui-deployment.yaml`) and
  scraped automatically through the annotation-based `kubernetes-pods` job.
- Dashboards are provisioned as code in
  `k8s/observability/grafana-dashboards.yaml` (one ConfigMap per service,
  in the "Services" Grafana folder). Update this file when adding new
  metrics so the dashboards stay in sync with what each service exposes.

## Code style

- Python 3.12, type hints required on every function (arguments and return).
- Docstrings in English, Google style (`Args:` / `Returns:`).
- Code comments in English.
- Request/response models always defined with Pydantic in `payments_api/payments_api/schemas.py`.
- New endpoints go in the router of the corresponding domain; do not create
  new routers unless necessary.

## Tests

- Framework: pytest. Run with `uv run pytest` from **inside `payments_api/`**
  (environment managed with uv: `uv venv` + `uv pip install -r requirements-dev.txt`,
  both from within `payments_api/`).
- One test file per router: if you touch `payments_api/payments_api/routers/health.py`,
  the tests go in `payments_api/tests/test_health.py`.
- Use FastAPI's `TestClient` (`from fastapi.testclient import TestClient`).
- Every new endpoint must have at least: one test for the status code and
  one test for the response content.
- Tests must pass green before committing.

## Git and Pull Requests

- Commits: conventional commits in English (`feat: ...`, `fix: ...`, `test: ...`).
- Branches: always `feature/<short-description>` branching off `main`.
  Never commit directly to `main`.
- PRs with a structured description: summary, changes, how to test
  (see the `pr-workflow` skill).

## Safety rules (MANDATORY)

- **Never merge PRs, only open them.** A human decides the merge.
- **Never apply changes to the Kubernetes cluster without explicit user
  approval.** This includes `kubectl apply`, `kubectl edit`, `kubectl patch`,
  `kubectl delete`, `kubectl scale` and any write operation via MCP.
  Diagnostics (get, describe, logs, events) are allowed.
- Never include secrets, tokens or credentials in code, manifests or PRs.
