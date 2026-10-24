#!/usr/bin/env bash
# ==============================================================================
# Teardown Script for Exercise 10
# Exercise 10: Multi-Node Kubernetes Cluster with Multiple Apps & ReplicaSets
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_NAME="devops-multinode"
MANIFESTS_DIR="${SCRIPT_DIR}/k8s-manifests"

echo "=== [1/3] Deleting Kubernetes Deployments & Services ==="
kubectl delete -f "${MANIFESTS_DIR}/product_catalog_service.yaml" --ignore-not-found=true
kubectl delete -f "${MANIFESTS_DIR}/shopping_cart_service.yaml" --ignore-not-found=true
kubectl delete -f "${MANIFESTS_DIR}/product_catalog_deployment.yaml" --ignore-not-found=true
kubectl delete -f "${MANIFESTS_DIR}/shopping_cart_deployment.yaml" --ignore-not-found=true

echo "=== [2/3] Cleaning Up Local Docker Images ==="
docker rmi -f product-catalog:latest shopping-cart:latest 2>/dev/null || true

echo "=== [3/3] Minikube Profile Management ==="
echo "To stop the 3-node cluster, run: minikube -p ${PROFILE_NAME} stop"
echo "To completely delete the cluster, run: minikube -p ${PROFILE_NAME} delete"
echo "Teardown completed."
