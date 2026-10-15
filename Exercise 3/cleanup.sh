#!/usr/bin/env bash
# ==============================================================================
# Teardown Script for Flash Sale ReplicaSet & Service
# Exercise 3: Scaling Flask App on Single Node using ReplicaSets
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Tearing down Flash Sale ReplicaSet & Service ==="
kubectl delete -f "${SCRIPT_DIR}/flashsale-replicaset.yaml" --ignore-not-found=true

echo "=== Verifying removal of resources ==="
kubectl get rs,pods,svc -l app=flashsale

echo "Cleanup completed successfully."
