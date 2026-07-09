.DEFAULT_GOAL := help

# Resolves to this Makefile's own directory (scripts/), regardless of
# where `make` is invoked from -- e.g. `make -C scripts test` or
# `cd scripts && make test` both work.
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT    := $(abspath $(MAKEFILE_DIR)/..)

SERVICE       ?= all
TAG           ?=
OBSERVABILITY ?= 0
EXTRA_ARGS    ?=

DEPLOY_FLAGS := --service $(SERVICE) $(if $(TAG),--tag $(TAG)) $(if $(filter 1,$(OBSERVABILITY)),--observability) $(EXTRA_ARGS)

.PHONY: help test setup-demo reset-demo break-demo deploy deploy-payment-api deploy-webui deploy-skip-deploy

help:
	@echo "Usage:"
	@echo "  make test                 Run payments_api tests (uv venv + pytest)"
	@echo "  make setup-demo           Create/refresh the kind cluster + deployments"
	@echo "  make reset-demo           Restore the healthy baseline deployment"
	@echo "  make break-demo           Deploy the broken payment-api-v2 (16Mi -> OOMKilled)"
	@echo "  make deploy               Manual build+push+deploy fallback for the CI/CD pipeline"
	@echo "  make deploy-payment-api   Same, scoped to payment-api"
	@echo "  make deploy-webui         Same, scoped to webui"
	@echo "  make deploy-skip-deploy   Build+push only, don't touch the cluster"
	@echo ""
	@echo "Overrides: SERVICE=payment-api|webui|all TAG=<tag> OBSERVABILITY=1 EXTRA_ARGS=\"...\""
	@echo "e.g.: make deploy SERVICE=payment-api TAG=develop OBSERVABILITY=1"

test:
	@echo ">> uv venv + uv pip install + uv run pytest: running payments_api's test suite"
	cd $(REPO_ROOT)/payments_api && uv venv --python 3.12 && uv pip install -r requirements-dev.txt && uv run pytest

setup-demo:
	@echo ">> setup-demo.sh: creating/refreshing the kind cluster and deploying payment-api + webui"
	$(MAKEFILE_DIR)setup-demo.sh

reset-demo:
	@echo ">> reset-demo.sh: deleting the broken deployment (if any) and restoring the healthy baseline"
	$(MAKEFILE_DIR)reset-demo.sh

break-demo:
	@echo ">> break-demo.sh: deploying payment-api-v2 with a 16Mi limit to force OOMKilled/CrashLoopBackOff"
	$(MAKEFILE_DIR)break-demo.sh

deploy:
	@echo ">> manual-build-deploy.sh $(DEPLOY_FLAGS): building, pushing to ECR and applying to EKS (service=$(SERVICE), tag=$(if $(TAG),$(TAG),auto))"
	$(MAKEFILE_DIR)manual-build-deploy.sh $(DEPLOY_FLAGS)

deploy-payment-api:
	@echo ">> manual-build-deploy.sh --service payment-api: building, pushing to ECR and applying payment-api to EKS"
	$(MAKEFILE_DIR)manual-build-deploy.sh --service payment-api $(if $(TAG),--tag $(TAG)) $(EXTRA_ARGS)

deploy-webui:
	@echo ">> manual-build-deploy.sh --service webui: building, pushing to ECR and applying webui to EKS"
	$(MAKEFILE_DIR)manual-build-deploy.sh --service webui $(if $(TAG),--tag $(TAG)) $(EXTRA_ARGS)

deploy-skip-deploy:
	@echo ">> manual-build-deploy.sh $(DEPLOY_FLAGS) --skip-deploy: building and pushing to ECR only, cluster untouched"
	$(MAKEFILE_DIR)manual-build-deploy.sh $(DEPLOY_FLAGS) --skip-deploy
