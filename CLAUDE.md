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
