# Demo: AI applied to DevOps

Project for a 45-minute talk with two live demos using Claude Code as the
agent:

1. **Demo 1 — Development:** the agent implements a new endpoint
   (`GET /health/detailed`) with tests, creates a branch and opens a
   Pull Request.
2. **Demo 2 — Operations:** a pod in Kubernetes fails (CrashLoopBackOff
   caused by OOMKilled); the agent diagnoses it by reading logs and events,
   proposes the fix and only applies it with explicit approval.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Claude Code (agent)                                 │
│  ├── CLAUDE.md ............ repo conventions        │
│  ├── .claude/skills/ ...... k8s-diagnostics,        │
│  │                          pr-workflow             │
│  ├── .claude/agents/ ...... sre-diagnostics,        │
│  │                          pr-reviewer             │
│  ├── GitHub MCP server .... branches, commits, PRs  │
│  └── Kubernetes MCP server. get/describe/logs/apply │
└──────────────┬──────────────────────────────────────┘
               │
   ┌───────────▼───────────┐      ┌───────────────────┐
   │ kind: demo-ai-devops  │      │ GitHub (repo)     │
   │  namespace: demo      │      │  PRs from Demo 1  │
   │  ├── payment-api (2x) │      └───────────────────┘
   │  │   128Mi/256Mi ✅   │
   │  ├── payment-api-v2   │
   │  │   16Mi → OOM 💥    │
   │  └── svc/payment-api  │
   └───────────────────────┘
```

`payment-api` is a payments microservice in Python/FastAPI with mock
endpoints (`/health`, `/payments`) and in-memory storage. Everything runs
locally: no cloud dependencies.

## Requirements

- [Docker](https://docs.docker.com/get-docker/) (daemon running)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Claude Code](https://claude.com/claude-code)
- MCP servers connected in Claude Code:
  - **GitHub MCP server** (Demo 1: branches, commits, PRs)
  - **Kubernetes MCP server** (Demo 2: cluster diagnosis and fix)
- [uv](https://docs.astral.sh/uv/) to run the app/tests outside Docker
- The repo published on GitHub with a configured remote (for Demo 1)

## Setup (in order)

```bash
# 1. Local dependencies to run the tests (with uv)
uv venv --python 3.12
uv pip install -r requirements-dev.txt
uv run pytest   # must pass green

# 2. Cluster + image + healthy deployment (idempotent)
./scripts/setup-demo.sh

# 3. Verify the service responds
kubectl port-forward svc/payment-api 8080:80 -n demo &
curl http://localhost:8080/health        # {"status":"ok"}
curl http://localhost:8080/payments      # mock list
```

Connect the GitHub and Kubernetes MCP servers in Claude Code
(`claude mcp add ...` or `/mcp`) before the talk and verify both respond.

## How to run each demo

The exact prompts to paste live are in [PROMPTS-DEMO.md](PROMPTS-DEMO.md).

### Demo 1 — endpoint + PR

1. Make sure you are on `main` with a clean tree and green tests.
2. Open Claude Code at the repo root and paste the Demo 1 prompt.
3. The agent implements `/health/detailed`, adds tests, runs
   `uv run pytest`, creates the `feature/*` branch and opens the PR.
   **You decide whether it gets merged** (live, the open PR is shown but
   not merged).

### Demo 2 — Kubernetes diagnosis

1. Right before the demo: `./scripts/break-demo.sh` (deploys
   `payment-api-v2` with a 16Mi limit → OOMKilled → CrashLoopBackOff).
2. Check the status: `kubectl get pods -n demo`.
3. Paste the Demo 2 prompt into Claude Code.
4. The agent diagnoses (describe → events → logs → limits), proposes the
   fix and **stops**. You approve live and the agent applies and verifies.

## Reset between rehearsals

```bash
# Deletes the broken deployment and restores the baseline
./scripts/reset-demo.sh
```

For Demo 1, additionally: close the rehearsal PR, delete the `feature/*`
branch and go back to `main` (`git checkout main && git branch -D feature/...`).

To start from scratch (cluster included):

```bash
kind delete cluster --name demo-ai-devops
./scripts/setup-demo.sh
```

## Project structure

```
├── CLAUDE.md              # Conventions the agent follows live
├── PROMPTS-DEMO.md        # Exact prompts for the 2 demos
├── app/                   # FastAPI microservice (payment-api)
├── tests/                 # pytest tests (one file per router)
├── Dockerfile             # Multi-stage, python:3.12-slim
├── k8s/                   # Manifests: healthy, broken and service
├── scripts/               # setup / break / reset
└── .claude/
    ├── skills/            # k8s-diagnostics, pr-workflow
    └── agents/            # sre-diagnostics, pr-reviewer
```
