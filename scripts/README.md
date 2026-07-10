# scripts/

Operational scripts for the local `kind` demo cluster and for the AWS
(EKS/ECR) environment. Run everything below from the repo root unless
noted otherwise.

## Makefile

A `Makefile` in this directory wraps the scripts below with a consistent
interface. Run it with `make -C scripts <target>` from the repo root, or
`cd scripts && make <target>`.

```bash
make -C scripts help
```

| Target                  | What it runs                | Description                                              |
| ------------------------ | ---------------------------- | ---------------------------------------------------------- |
| `test`                  | `uv venv` + `uv run pytest` | Runs the `payments_api` test suite                        |
| `setup-demo`            | `setup-demo.sh`             | Creates/refreshes the kind cluster and deploys both apps  |
| `reset-demo`            | `reset-demo.sh`             | Deletes the broken deployment (if any) and restores baseline |
| `break-demo`            | `break-demo.sh`             | Deploys `payment-api-v2` with a 16Mi limit (OOMKilled)     |
| `deploy`                | `manual-build-deploy.sh`    | Manual build + push to ECR + apply to EKS (both services) |
| `deploy-payment-api`    | `manual-build-deploy.sh`    | Same, scoped to `payment-api`                             |
| `deploy-webui`          | `manual-build-deploy.sh`    | Same, scoped to `webui`                                   |
| `deploy-skip-deploy`    | `manual-build-deploy.sh`    | Build + push only, doesn't touch the cluster              |

Overrides (pass as `make deploy VAR=value`):

- `SERVICE` — `payment-api` \| `webui` \| `all` (default: `all`)
- `TAG` — image tag to build/push/deploy (default: `sha-<short git sha>`)
- `OBSERVABILITY` — `1` to also apply `k8s/observability/` (default: `0`)
- `EXTRA_ARGS` — extra flags forwarded verbatim to the underlying script

```bash
make -C scripts deploy SERVICE=payment-api TAG=develop OBSERVABILITY=1
```

Every target echoes the exact command it's about to run before running it.

## Scripts (local kind cluster)

- **`setup-demo.sh`** — idempotent. Creates the `demo-ai-devops` kind
  cluster if missing, builds the `payment-api` and `webui` images locally,
  loads them into the cluster with `kind load`, and applies the `k8s/`
  manifests.
- **`break-demo.sh`** — deploys `payment-api-v2` with a 16Mi memory limit,
  which gets OOMKilled and enters `CrashLoopBackOff`. Requires
  `setup-demo.sh` to have run first (needs the `kind-demo-ai-devops`
  context).
- **`reset-demo.sh`** — deletes `payment-api-v2` if present and restores
  the healthy `payment-api` deployment + service from `k8s/`.

## Scripts (AWS: EKS + ECR)

- **`manual-build-deploy.sh`** — manual fallback for the CI/CD pipeline
  (`.github/workflows/build-payments-api.yml`,
  `build-webui.yml`, `deploy-payments-api.yml`, `deploy-webui.yml`). Use it
  from your machine if GitHub Actions is unavailable: it builds the
  images, pushes them to ECR and applies the same manifests to EKS that
  the workflows apply, with the same defaults (region `us-east-1`,
  cluster `modern-ai-strategies-dev`, namespace `demo`).

  Requires `docker`, the `aws` CLI (authenticated with an identity that
  can push to ECR and reach the EKS cluster) and `kubectl`.

  ```bash
  ./scripts/manual-build-deploy.sh                          # build+push+deploy both services
  ./scripts/manual-build-deploy.sh --service payment-api    # scope to one service
  ./scripts/manual-build-deploy.sh --skip-build --skip-push # redeploy an image already in ECR
  ./scripts/manual-build-deploy.sh --tag develop            # deploy a specific tag
  ./scripts/manual-build-deploy.sh --observability           # also apply k8s/observability/
  ./scripts/manual-build-deploy.sh --help                    # full option list
  ```

  This touches real AWS infrastructure (pushes images, runs `kubectl
  apply` against EKS) — run it deliberately, not as part of an automated
  flow.
