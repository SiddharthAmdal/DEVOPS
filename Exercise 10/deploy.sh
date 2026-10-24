#!/usr/bin/env bash
# ==============================================================================
# Deploy Multi-Node Microservices onto Minikube
# Exercise 10: Multi-Node Kubernetes Cluster with Multiple Apps & ReplicaSets
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_NAME="devops-multinode"
MANIFESTS_DIR="${SCRIPT_DIR}/k8s-manifests"

echo "=== [1/5] Checking Minikube Multi-Node Cluster Status ==="
if ! minikube -p "${PROFILE_NAME}" status >/dev/null 2>&1; then
    echo "Starting 3-node Minikube cluster (profile: ${PROFILE_NAME})..."
    minikube start --nodes 3 -p "${PROFILE_NAME}" --driver=docker
else
    echo "Minikube cluster '${PROFILE_NAME}' is already running."
fi

# Verify nodes
echo ""
echo "Cluster nodes:"
kubectl get nodes -o wide

echo ""
echo "=== [2/5] Building Local Docker Images ==="
cd "${SCRIPT_DIR}"
echo "Building product-catalog:latest..."
docker build -t product-catalog:latest -f Dockerfile.product .
echo "Building shopping-cart:latest..."
docker build -t shopping-cart:latest -f Dockerfile.shopping .

echo ""
echo "=== [3/5] Loading Images into Minikube Multi-Node Cluster ==="
echo "Loading product-catalog:latest into '${PROFILE_NAME}'..."
minikube -p "${PROFILE_NAME}" image load product-catalog:latest
echo "Loading shopping-cart:latest into '${PROFILE_NAME}'..."
minikube -p "${PROFILE_NAME}" image load shopping-cart:latest

echo ""
echo "=== [4/5] Applying Kubernetes Deployments & Services ==="
kubectl apply -f "${MANIFESTS_DIR}/product_catalog_deployment.yaml"
kubectl apply -f "${MANIFESTS_DIR}/shopping_cart_deployment.yaml"
kubectl apply -f "${MANIFESTS_DIR}/product_catalog_service.yaml"
kubectl apply -f "${MANIFESTS_DIR}/shopping_cart_service.yaml"

echo ""
echo "Waiting for deployments to roll out..."
kubectl rollout status deployment/product-catalog --timeout=90s
kubectl rollout status deployment/shopping-cart --timeout=90s

echo ""
echo "=== [5/5] Pod Node Distribution Verification ==="
echo "Displaying pod distribution across cluster nodes:"
kubectl get pods -o wide --selector="app in (product-catalog, shopping-cart)"

echo ""
echo "Deployment successful! To test endpoints, run: ./'Exercise 10'/test-services.sh"
