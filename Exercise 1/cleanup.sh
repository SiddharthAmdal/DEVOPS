#!/usr/bin/env bash
# ==============================================================================
# Zepto Storefront Teardown Script
# Exercise 1: Hello Pod
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Tearing down Zepto Storefront resources ==="
kubectl delete -f "${SCRIPT_DIR}/service.yaml" --ignore-not-found=true
kubectl delete -f "${SCRIPT_DIR}/pod.yaml" --ignore-not-found=true

echo "=== Verifying resources removal ==="
kubectl get pods,svc -l app=hello-k8s

echo "Cleanup completed successfully."
