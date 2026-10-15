#!/usr/bin/env bash
# ==============================================================================
# Build & Deploy Flask App to Minikube
# Exercise 2: Deploy a Flask App on Minikube using kubectl and YAML
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="flask-app:latest"
DEPLOYMENT_NAME="flask-app"
SERVICE_NAME="flask-app-service"

echo "=== [1/4] Building Docker Image directly inside Minikube ==="
if command -v minikube >/dev/null 2>&1; then
    minikube image build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
else
    eval $(minikube docker-env)
    docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"
fi

echo "=== [2/4] Applying Deployment & Service Manifests ==="
kubectl apply -f "${SCRIPT_DIR}/flask-deployment.yaml"

echo "=== [3/4] Waiting for Deployment Rollout ==="
kubectl rollout status deployment/"${DEPLOYMENT_NAME}" --timeout=90s

echo "=== [4/4] Verifying Resources & Endpoints ==="
echo "--- Deployment & Pods ---"
kubectl get deployment "${DEPLOYMENT_NAME}" -o wide
kubectl get pods -l app=flask-app -o wide

echo "--- Service & Endpoints ---"
kubectl get svc "${SERVICE_NAME}" -o wide
kubectl get endpoints "${SERVICE_NAME}"

echo ""
echo "=== Deployment Successful! ==="
echo "Access the Flask application using:"
echo "  1) Minikube Service Tunnel: minikube service ${SERVICE_NAME} --url"
echo "  2) Port-Forwarding:         kubectl port-forward service/${SERVICE_NAME} 15000:15000"
