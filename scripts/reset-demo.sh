#!/usr/bin/env bash
# Removes the broken deployment and restores the healthy baseline,
# leaving the cluster ready to rehearse the demo again.
set -euo pipefail

CLUSTER_NAME="demo-ai-devops"
NAMESPACE="demo"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v kubectl &>/dev/null; then
  echo "ERROR: 'kubectl' is not installed or not in PATH." >&2
  exit 1
fi

if ! kubectl config get-contexts "kind-$CLUSTER_NAME" &>/dev/null; then
  echo "ERROR: context 'kind-$CLUSTER_NAME' does not exist. Run scripts/setup-demo.sh first." >&2
  exit 1
fi

kubectl config use-context "kind-$CLUSTER_NAME" >/dev/null

echo "==> Deleting old broken deployment (payment-api-v2) if it exists..."
kubectl delete deployment payment-api-v2 -n "$NAMESPACE" --ignore-not-found

echo "==> Restoring payment-api deployment and service..."
kubectl apply -f "$REPO_ROOT/k8s/deployment-payment-api.yaml"
kubectl apply -f "$REPO_ROOT/k8s/payment-api-service.yaml"
kubectl rollout status deployment/payment-api -n "$NAMESPACE" --timeout=120s

echo ""
echo "🔄 Clean state. Namespace '$NAMESPACE':"
kubectl get pods,svc -n "$NAMESPACE"
