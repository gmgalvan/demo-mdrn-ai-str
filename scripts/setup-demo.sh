#!/usr/bin/env bash
# Sets up the full demo environment: kind cluster, image, namespace,
# healthy deployment and service. Safe to run multiple times (idempotent).
set -euo pipefail

CLUSTER_NAME="demo-ai-devops"
IMAGE="payment-api:demo"
WEBUI_IMAGE="webui:demo"
NAMESPACE="demo"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Check prerequisites ---
check_binary() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is not installed or not in PATH. $2" >&2
    exit 1
  fi
}

check_binary docker "Install it from https://docs.docker.com/get-docker/"
check_binary kind "Install it from https://kind.sigs.k8s.io/docs/user/quick-start/"
check_binary kubectl "Install it from https://kubernetes.io/docs/tasks/tools/"

if ! docker info &>/dev/null; then
  echo "ERROR: the Docker daemon is not running. Start Docker and retry." >&2
  exit 1
fi

# --- Create kind cluster (skip if it already exists) ---
if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
  echo "==> kind cluster '$CLUSTER_NAME' already exists, reusing it."
else
  echo "==> Creating kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME"
fi

kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

# --- Build and load the images ---
echo "==> Building image $IMAGE..."
docker build -t "$IMAGE" "$REPO_ROOT/payments_api"

echo "==> Building image $WEBUI_IMAGE..."
docker build -t "$WEBUI_IMAGE" "$REPO_ROOT/webui"

echo "==> Loading images into the cluster..."
kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"
kind load docker-image "$WEBUI_IMAGE" --name "$CLUSTER_NAME"

# --- Namespace, deployments and services (apply is idempotent) ---
echo "==> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying payment-api deployment and service..."
kubectl apply -f "$REPO_ROOT/k8s/deployment-payment-api.yaml"
kubectl apply -f "$REPO_ROOT/k8s/payment-api-service.yaml"

echo "==> Applying webui deployment and service..."
kubectl apply -f "$REPO_ROOT/k8s/webui-deployment.yaml"
kubectl apply -f "$REPO_ROOT/k8s/webui-service.yaml"

echo "==> Waiting for payment-api to be ready..."
kubectl rollout status deployment/payment-api -n "$NAMESPACE" --timeout=120s

echo "==> Waiting for webui to be ready..."
kubectl rollout status deployment/webui -n "$NAMESPACE" --timeout=120s

echo ""
echo "✅ Demo ready. Status of namespace '$NAMESPACE':"
kubectl get pods,svc -n "$NAMESPACE"
echo ""
echo "To try the API directly:"
echo "  kubectl port-forward svc/payment-api 8080:80 -n $NAMESPACE"
echo "  curl http://localhost:8080/health"
echo ""
echo "To try the web UI:"
echo "  kubectl port-forward svc/webui 4200:80 -n $NAMESPACE"
echo "  open http://localhost:4200"
