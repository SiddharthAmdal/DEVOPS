#!/usr/bin/env bash
# ==============================================================================
# Teardown Script for Flask App
# Exercise 2: Deploy a Flask App on Minikube using kubectl and YAML
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Tearing down Flask App Deployment & Service ==="
kubectl delete -f "${SCRIPT_DIR}/flask-deployment.yaml" --ignore-not-found=true

echo "=== Verifying removal of resources ==="
kubectl get deployments,pods,svc -l app=flask-app

echo "Cleanup completed successfully."
