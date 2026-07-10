#!/usr/bin/env bash
# Manual fallback for the CI/CD pipeline (build-payments-api.yml,
# build-webui.yml, deploy-payments-api.yml, deploy-webui.yml). Use this
# from your laptop if GitHub Actions is unavailable during a live demo:
# it builds the images, pushes them to ECR and applies the same manifests
# to EKS that the workflows apply, with the same defaults.
#
# Requires: docker, aws CLI (logged in with an identity that can push to
# ECR and reach the EKS cluster), kubectl.
#
# Usage:
#   ./scripts/manual-build-deploy.sh [options]
#
# Options:
#   --service <payment-api|webui|all>   Default: all
#   --tag <tag>                         Default: sha-<short git sha>
#   --skip-build                        Skip docker build (image must already exist locally)
#   --skip-push                         Skip docker push (use an image already in ECR)
#   --skip-deploy                       Only build/push, don't touch the cluster
#   --observability                     Also apply k8s/observability/ (payment-api only, like the workflow)
#   -h, --help                          Show this help
#
# Env overrides (same defaults as the GitHub Actions workflows):
#   AWS_REGION          default: us-east-1
#   EKS_CLUSTER_NAME     default: modern-ai-strategies-dev
#   K8S_NAMESPACE        default: demo
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AWS_REGION="${AWS_REGION:-us-east-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-modern-ai-strategies-dev}"
K8S_NAMESPACE="${K8S_NAMESPACE:-demo}"

SERVICE="all"
TAG=""
SKIP_BUILD=false
SKIP_PUSH=false
SKIP_DEPLOY=false
DEPLOY_OBSERVABILITY=false

usage() {
  sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service) SERVICE="$2"; shift 2 ;;
    --tag) TAG="$2"; shift 2 ;;
    --skip-build) SKIP_BUILD=true; shift ;;
    --skip-push) SKIP_PUSH=true; shift ;;
    --skip-deploy) SKIP_DEPLOY=true; shift ;;
    --observability) DEPLOY_OBSERVABILITY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option '$1'" >&2; usage; exit 1 ;;
  esac
done

if [[ "$SERVICE" != "all" && "$SERVICE" != "payment-api" && "$SERVICE" != "webui" ]]; then
  echo "ERROR: --service must be 'payment-api', 'webui' or 'all'." >&2
  exit 1
fi

for cmd in docker aws kubectl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "ERROR: '$cmd' is not installed or not in PATH." >&2
    exit 1
  fi
done

if [[ -z "$TAG" ]]; then
  TAG="sha-$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
fi

echo "==> Resolving AWS account and ECR registry..."
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "    Account: $ACCOUNT_ID"
echo "    Registry: $ECR_REGISTRY"
echo "    Tag: $TAG"

services_to_run=()
if [[ "$SERVICE" == "all" ]]; then
  services_to_run=(payment-api webui)
else
  services_to_run=("$SERVICE")
fi

if [[ "$SKIP_BUILD" == false || "$SKIP_PUSH" == false ]]; then
  echo "==> Logging in to Amazon ECR..."
  aws ecr get-login-password --region "$AWS_REGION" |
    docker login --username AWS --password-stdin "$ECR_REGISTRY"
fi

build_and_push() {
  local service="$1" context="$2"
  local image="${ECR_REGISTRY}/${service}:${TAG}"

  if [[ "$SKIP_BUILD" == false ]]; then
    echo "==> Building ${service} (${image})..."
    docker build --platform linux/amd64 -t "$image" -f "${context}/Dockerfile" "$context"
  else
    echo "==> Skipping build for ${service}"
  fi

  if [[ "$SKIP_PUSH" == false ]]; then
    echo "==> Pushing ${image}..."
    docker push "$image"
  else
    echo "==> Skipping push for ${service}"
  fi
}

context_dir_for() {
  case "$1" in
    payment-api) echo "${REPO_ROOT}/payments_api" ;;
    webui) echo "${REPO_ROOT}/webui" ;;
  esac
}

for svc in "${services_to_run[@]}"; do
  build_and_push "$svc" "$(context_dir_for "$svc")"
done

if [[ "$SKIP_DEPLOY" == true ]]; then
  echo "==> --skip-deploy set, not touching the cluster. Done."
  exit 0
fi

echo "==> Updating kubeconfig for EKS cluster '${EKS_CLUSTER_NAME}'..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"

echo "==> Ensuring namespace '${K8S_NAMESPACE}' exists..."
kubectl create namespace "$K8S_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

deploy_service() {
  local service="$1" deployment_manifest="$2" service_manifest="$3" deployment_name="$4"
  local image="${ECR_REGISTRY}/${service}:${TAG}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  echo "==> Rendering manifests for ${service}..."
  sed \
    -e "s|namespace: demo|namespace: ${K8S_NAMESPACE}|g" \
    -e "s|image: ${service}:demo|image: ${image}|g" \
    -e "s|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g" \
    "$deployment_manifest" > "${tmp_dir}/deployment.yaml"

  sed \
    -e "s|namespace: demo|namespace: ${K8S_NAMESPACE}|g" \
    "$service_manifest" > "${tmp_dir}/service.yaml"

  echo "==> Applying ${service}..."
  kubectl apply -f "${tmp_dir}/deployment.yaml"
  kubectl apply -f "${tmp_dir}/service.yaml"
  kubectl rollout status "deployment/${deployment_name}" -n "$K8S_NAMESPACE" --timeout=180s

  rm -rf "$tmp_dir"
}

for svc in "${services_to_run[@]}"; do
  case "$svc" in
    payment-api)
      deploy_service payment-api \
        "${REPO_ROOT}/k8s/deployment-payment-api.yaml" \
        "${REPO_ROOT}/k8s/payment-api-service.yaml" \
        payment-api
      ;;
    webui)
      deploy_service webui \
        "${REPO_ROOT}/k8s/webui-deployment.yaml" \
        "${REPO_ROOT}/k8s/webui-service.yaml" \
        webui
      ;;
  esac
done

if [[ "$DEPLOY_OBSERVABILITY" == true ]]; then
  echo "==> Deploying observability stack..."
  kubectl apply -f "${REPO_ROOT}/k8s/observability/namespace.yaml"
  kubectl apply -f "${REPO_ROOT}/k8s/observability/"

  kubectl rollout status deployment/prometheus -n observability --timeout=180s
  kubectl rollout status deployment/grafana -n observability --timeout=180s
  kubectl rollout status deployment/loki -n observability --timeout=180s
  kubectl rollout status daemonset/promtail -n observability --timeout=180s

  kubectl get pods,svc -n observability
fi

echo ""
echo "✅ Done. Namespace '${K8S_NAMESPACE}':"
kubectl get pods,svc -n "$K8S_NAMESPACE"
