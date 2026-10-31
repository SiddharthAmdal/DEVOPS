#!/usr/bin/env bash
# ==============================================================================
# Teardown and Cleanup Script for Food Delivery Platform Lab
# DevOps CIE: Question 3
# ==============================================================================

set -euo pipefail

NETWORK_NAME="food-delivery-net"
MYSQL_CONTAINER="mysql"
REDIS_CONTAINER="redis"
FLASK_CONTAINER="flask-order-service"
SECURITY_TEST_CONTAINER="security-test-container"

echo "=== [1/2] Stopping and Removing Containers ==="
docker rm -f "${FLASK_CONTAINER}" "${MYSQL_CONTAINER}" "${REDIS_CONTAINER}" "${SECURITY_TEST_CONTAINER}" 2>/dev/null || true
echo "✓ Containers removed."

echo "=== [2/2] Removing Custom Bridge Network ==="
docker network rm "${NETWORK_NAME}" 2>/dev/null || true
echo "✓ Network '${NETWORK_NAME}' removed."

echo ""
echo "Cleanup completed successfully."
