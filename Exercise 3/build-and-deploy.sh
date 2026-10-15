#!/usr/bin/env bash
# ==============================================================================
# Build & Deploy Flash Sale App to Minikube
# Exercise 3: Scaling Flask App on Single Node using ReplicaSets
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="flashsale:1.0"
RS_NAME="flashsale-rs"
SERVICE_NAME="flashsale-svc"

echo "=== [1/4] Building Docker Image directly inside Minikube ==="
if command -v minikube >/dev/null 2>&1; then
    minikube image build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
else
    eval $(minikube docker-env)
    docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
fi

echo "=== [2/4] Applying ReplicaSet & Service Manifests ==="
kubectl apply -f "${SCRIPT_DIR}/flashsale-replicaset.yaml"

echo "=== [3/4] Waiting for Initial 3 Replicas to be Ready ==="
kubectl wait --for=condition=Ready pod -l app=flashsale --timeout=60s

echo "=== [4/4] Verifying ReplicaSet & Service Status ==="
echo "--- ReplicaSet Status ---"
kubectl get rs "${RS_NAME}"

echo "--- Active Pods ---"
kubectl get pods -l app=flashsale -o wide

echo "--- Registered Endpoints ---"
kubectl get endpoints "${SERVICE_NAME}"

echo ""
echo "=== Deployment Successful! ==="
echo "Test the Flash Sale app:"
echo "  1) Port-Forward Service: kubectl port-forward service/${SERVICE_NAME} 8080:80"
echo "  2) Simulate Purchases:   curl http://localhost:8080/buy"
echo "  3) Scale Replicas:       ./scale.sh 5"
