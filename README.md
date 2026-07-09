# payment-api & webui

A payments platform used to explore AI-assisted development and DevOps
workflows with Claude Code.

`payment-api` is a Python/FastAPI payments microservice with mock endpoints
(`/health`, `/payments`) and in-memory storage — no cloud dependencies.
`webui` ([webui/](webui/)) is an Angular frontend for it: it lists payments,
shows the backend's health status and lets you create new payments. It is
served by nginx, which reverse-proxies `/api/` to the `payment-api` Service
so the browser never talks to the backend directly. Both run on a local
`kind` Kubernetes cluster alongside a Prometheus/Grafana/Loki observability
stack.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│ Claude Code (agent)                                 │
│  ├── CLAUDE.md ............ repo conventions        │
│  ├── .claude/skills/ ...... k8s-diagnostics,        │
│  │                          pr-workflow             │
│  ├── .claude/agents/ ...... sre-diagnostics,        │
│  │                          pr-reviewer             │
│  └── GitHub MCP server .... branches, commits, PRs  │
└──────────────┬──────────────────────────────────────┘
               │
   ┌───────────▼───────────┐      ┌───────────────────┐
   │ kind: demo-ai-devops  │      │ GitHub (repo)     │
   │  namespace: demo      │      └───────────────────┘
   │  ├── payment-api (1x) │
   │  │   128Mi/256Mi ✅   │
   │  ├── svc/payment-api  │
   │  ├── webui (1x)       │
   │  │   nginx + Angular  │
   │  └── svc/webui        │
   └───────────────────────┘

   ┌─────────────────────────────────────────────────┐
   │ namespace: observability                        │
   │  ├── prometheus  (scrapes payment-api /metrics  │
   │  │                 and webui's nginx-exporter)  │
   │  ├── grafana     (dashboards provisioned from   │
   │  │                 k8s/observability/*.yaml)    │
   │  ├── loki                                       │
   │  └── promtail    (ships pod logs to loki)       │
   └─────────────────────────────────────────────────┘
```

## Requirements

- [Docker](https://docs.docker.com/get-docker/) (daemon running)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Claude Code](https://claude.com/claude-code)
- **GitHub MCP server** connected in Claude Code (branches, commits, PRs)
- [uv](https://docs.astral.sh/uv/) to run the app/tests outside Docker
- [Node.js](https://nodejs.org/) 22+ and npm to run `webui` outside Docker
  (optional: the cluster setup script builds it into an image, no local
  Node required just to run `setup-demo.sh`)
- The repo published on GitHub with a configured remote (to open PRs)

## Setup (in order)

```bash
# 1. Local dependencies to run the tests (with uv, from inside payments_api/)
cd payments_api
uv venv --python 3.12
uv pip install -r requirements-dev.txt
uv run pytest   # must pass green
cd ..
```

The primary deployment target is a real **AWS EKS** cluster, provisioned
with Terraform (`infra/`, see [infra/README.md](infra/README.md) for the
networking/compute/services layers and ECR repositories) and deployed to
via **GitHub Actions**:

- `build-payments-api.yml` / `build-webui.yml` build and push images to
  ECR on every push to `develop`.
- `deploy-payments-api.yml` / `deploy-webui.yml` (`workflow_dispatch`)
  apply the `k8s/` manifests to EKS with a given image tag.

If the pipeline is unavailable, `scripts/manual-build-deploy.sh` (or
`make -C scripts deploy`) does the same build → push → apply steps by
hand — see [scripts/README.md](scripts/README.md).

Once deployed, point `kubectl` at the cluster and verify:

```bash
aws eks update-kubeconfig --region us-east-1 --name modern-ai-strategies-dev

kubectl port-forward svc/payment-api 8080:80 -n demo &
curl http://localhost:8080/health        # {"status":"ok"}
curl http://localhost:8080/payments      # mock list

kubectl port-forward svc/webui 4200:80 -n demo &
open http://localhost:4200                # or visit it in a browser

kubectl port-forward svc/grafana 3000:3000 -n observability &
kubectl port-forward svc/prometheus 9090:9090 -n observability &
open http://localhost:3000                # Grafana: Services folder
```

Connect the GitHub MCP server in Claude Code (`claude mcp add ...` or
`/mcp`) and verify it responds.

### Local development (optional, no AWS required)

`scripts/setup-demo.sh` / `break-demo.sh` / `reset-demo.sh` spin up the
same `payment-api` + `webui` manifests on a local `kind` cluster instead
of EKS — useful to iterate offline without touching real AWS resources.
See [scripts/README.md](scripts/README.md) for details.

## Project structure

```
├── CLAUDE.md              # Repo conventions for the agent
├── payments_api/          # Self-contained FastAPI microservice (payment-api)
│   ├── payments_api/      # Python package (main.py, routers/, schemas.py)
│   ├── tests/             # pytest tests (one file per router)
│   ├── pyproject.toml, requirements*.txt, uv.lock
│   └── Dockerfile         # Multi-stage, python:3.12-slim
├── webui/                 # Angular frontend for payment-api
│   ├── src/app/           # PaymentsService + PaymentsDashboardComponent
│   ├── Dockerfile         # Multi-stage, node build + nginx runtime
│   └── nginx.conf.template  # Static files + /api/ reverse proxy + stub_status
├── k8s/                   # Manifests: payment-api, webui, service
│   └── observability/     # Prometheus, Grafana, Loki, Promtail
├── scripts/               # setup / break / reset
└── .claude/
    ├── mcp/.mcp.json      # Tracked reference copy of the MCP server config
    │                      #   (the file Claude Code actually loads is the
    │                      #   gitignored .mcp.json at the repo root)
    ├── skills/            # k8s-diagnostics, pr-workflow
    └── agents/            # sre-diagnostics, pr-reviewer
```
