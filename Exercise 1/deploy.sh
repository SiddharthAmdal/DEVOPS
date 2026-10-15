#!/usr/bin/env bash
# ==============================================================================
# Zepto Storefront Deployment Automation Script
# Exercise 1: Hello Pod
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POD_NAME="hello-k8s"
SERVICE_NAME="hello-k8s"

echo "=== [1/4] Applying Declarative Pod Manifest ==="
kubectl apply -f "${SCRIPT_DIR}/pod.yaml"

echo "=== [2/4] Waiting for Pod to be in 'Ready' state ==="
kubectl wait --for=condition=Ready pod/"${POD_NAME}" --timeout=60s

echo "=== [3/4] Applying Declarative Service Manifest ==="
kubectl apply -f "${SCRIPT_DIR}/service.yaml"

echo "=== [4/4] Verifying Deployment Status ==="
echo "--- Pod Details ---"
kubectl get pod "${POD_NAME}" -o wide

echo "--- Service Details ---"
kubectl get svc "${SERVICE_NAME}" -o wide

echo "--- Registered Endpoints ---"
kubectl get endpoints "${SERVICE_NAME}"

echo ""
echo "=== Deployment Successful! ==="
echo "Access the Zepto Storefront using:"
echo "  1) Minikube Tunnel: minikube service ${SERVICE_NAME}"
echo "  2) Port-Forward:    kubectl port-forward service/${SERVICE_NAME} 8080:80"
