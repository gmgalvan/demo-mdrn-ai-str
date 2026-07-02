#!/usr/bin/env bash
# Deploys the broken payment-api-v2 (16Mi memory limit -> OOMKilled ->
# CrashLoopBackOff). Run this right before Demo 2.
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

echo "==> Applying broken deployment (payment-api-v2)..."
kubectl apply -f "$REPO_ROOT/k8s/deployment-broken.yaml"

echo "==> Waiting a few seconds for the pod to start failing..."
sleep 15

echo ""
echo "💥 Current status (the pod should be in CrashLoopBackOff / OOMKilled):"
kubectl get pods -n "$NAMESPACE" -l app=payment-api-v2
echo ""
echo "Ready for Demo 2. Ask the agent to diagnose payment-api-v2."
