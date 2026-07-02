#!/usr/bin/env bash
# Sets up the full demo environment: kind cluster, image, namespace,
# healthy deployment and service. Safe to run multiple times (idempotent).
set -euo pipefail

CLUSTER_NAME="demo-ai-devops"
IMAGE="payment-api:demo"
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

# --- Build and load the image ---
echo "==> Building image $IMAGE..."
docker build -t "$IMAGE" "$REPO_ROOT"

echo "==> Loading image into the cluster..."
kind load docker-image "$IMAGE" --name "$CLUSTER_NAME"

# --- Namespace, deployment and service (apply is idempotent) ---
echo "==> Creating namespace '$NAMESPACE'..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying healthy deployment and service..."
kubectl apply -f "$REPO_ROOT/k8s/deployment-healthy.yaml"
kubectl apply -f "$REPO_ROOT/k8s/service.yaml"

echo "==> Waiting for payment-api to be ready..."
kubectl rollout status deployment/payment-api -n "$NAMESPACE" --timeout=120s

echo ""
echo "✅ Demo ready. Status of namespace '$NAMESPACE':"
kubectl get pods,svc -n "$NAMESPACE"
echo ""
echo "To try the service:"
echo "  kubectl port-forward svc/payment-api 8080:80 -n $NAMESPACE"
echo "  curl http://localhost:8080/health"
