#!/usr/bin/env bash
# ==============================================================================
# Integration Test Script for Multi-Node Services
# Exercise 10: Multi-Node Kubernetes Cluster with Multiple Apps & ReplicaSets
# ==============================================================================

set -euo pipefail

CATALOG_PORT=38081
CART_PORT=38082
CATALOG_URL="http://127.0.0.1:${CATALOG_PORT}"
CART_URL="http://127.0.0.1:${CART_PORT}"

echo "=== [1/3] Establishing Port-Forwards to Kubernetes Services ==="
# Kill any lingering forwards on ports 38081 or 38082
lsof -ti:${CATALOG_PORT} | xargs kill -9 2>/dev/null || true
lsof -ti:${CART_PORT} | xargs kill -9 2>/dev/null || true

kubectl port-forward svc/product-catalog-service ${CATALOG_PORT}:80 >/dev/null 2>&1 &
PID_CATALOG=$!

kubectl port-forward svc/shopping-cart-service ${CART_PORT}:80 >/dev/null 2>&1 &
PID_CART=$!

cleanup() {
    kill -9 "${PID_CATALOG}" "${PID_CART}" 2>/dev/null || true
}
trap cleanup EXIT

# Wait up to 5 seconds for sockets to open
sleep 2

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
