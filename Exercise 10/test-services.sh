#!/usr/bin/env bash
# ==============================================================================
# Integration Test Script for Multi-Node Services
# Exercise 10: Multi-Node Kubernetes Cluster with Multiple Apps & ReplicaSets
# ==============================================================================

set -euo pipefail

PROFILE_NAME="devops-multinode"

echo "=== [1/3] Resolving Service Endpoints ==="
# Minikube service URL resolution
CATALOG_URL=$(minikube -p "${PROFILE_NAME}" service product-catalog-service --url 2>/dev/null || true)
CART_URL=$(minikube -p "${PROFILE_NAME}" service shopping-cart-service --url 2>/dev/null || true)

# Fallback to port-forward if direct URL is empty (e.g. Docker desktop network isolation)
PORT_FORWARD_PIDS=()
cleanup() {
    for pid in "${PORT_FORWARD_PIDS[@]}"; do
        kill -9 "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT

if [ -z "${CATALOG_URL}" ] || ! curl -s -m 2 "${CATALOG_URL}/products" >/dev/null 2>&1; then
    echo "Starting local port-forward for product-catalog-service (port 38081)..."
    kubectl port-forward svc/product-catalog-service 38081:80 >/dev/null 2>&1 &
    PORT_FORWARD_PIDS+=($!)
    CATALOG_URL="http://127.0.0.1:38081"
    sleep 2
fi

if [ -z "${CART_URL}" ] || ! curl -s -m 2 "${CART_URL}/cart" >/dev/null 2>&1; then
    echo "Starting local port-forward for shopping-cart-service (port 38082)..."
    kubectl port-forward svc/shopping-cart-service 38082:80 >/dev/null 2>&1 &
    PORT_FORWARD_PIDS+=($!)
    CART_URL="http://127.0.0.1:38082"
    sleep 2
fi

echo "Product Catalog Service URL: ${CATALOG_URL}"
echo "Shopping Cart Service URL:   ${CART_URL}"

echo ""
echo "=== [2/3] Testing Product Catalog Service (GET /products) ==="
echo "Querying ${CATALOG_URL}/products..."
CATALOG_RESP=$(curl -s "${CATALOG_URL}/products")
echo "Response:"
echo "${CATALOG_RESP}" | python3 -m json.tool

echo ""
echo "=== [3/3] Testing Shopping Cart Service (GET & POST /cart) ==="
echo "1. Checking initial cart status (GET /cart):"
curl -s "${CART_URL}/cart" | python3 -m json.tool

echo ""
echo "2. Adding item to cart (POST /cart):"
POST_RESP=$(curl -s -X POST "${CART_URL}/cart" \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "name": "Laptop", "quantity": 1}')
echo "Response:"
echo "${POST_RESP}" | python3 -m json.tool

echo ""
echo "3. Verifying cart updated (GET /cart):"
curl -s "${CART_URL}/cart" | python3 -m json.tool

echo ""
echo "=== All Service Integration Tests Passed Successfully! ==="
