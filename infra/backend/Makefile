.DEFAULT_GOAL := help

PROJECT_NAME ?= modern-ai-strategies
ENVIRONMENT  ?= dev
AWS_REGION   ?= us-east-1

.PHONY: help create destroy

help:
	@echo "Usage:"
	@echo "  make create   Create the S3 bucket + DynamoDB table backend and generate backend.$(ENVIRONMENT).hcl per layer"
	@echo "  make destroy  Permanently delete the backend bucket (all state!) and lock table (asks for confirmation)"
	@echo ""
	@echo "Override PROJECT_NAME, ENVIRONMENT or AWS_REGION, e.g.: make create ENVIRONMENT=prod"

create:
	PROJECT_NAME=$(PROJECT_NAME) ENVIRONMENT=$(ENVIRONMENT) AWS_REGION=$(AWS_REGION) ./bootstrap-backend.sh

destroy:
	PROJECT_NAME=$(PROJECT_NAME) ENVIRONMENT=$(ENVIRONMENT) AWS_REGION=$(AWS_REGION) ./destroy-backend.sh
