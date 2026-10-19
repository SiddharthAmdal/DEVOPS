#!/usr/bin/env bash
# ==============================================================================
# Teardown Script for Docker Networking Lab
# Exercise 4: Docker Networking with Multiple Containers
# ==============================================================================

set -euo pipefail

NETWORK_NAME="my-bridge-net"

echo "=== Stopping and removing containers: mysql, redis, flask ==="
docker stop mysql redis flask 2>/dev/null || true
docker rm mysql redis flask 2>/dev/null || true

echo "=== Removing custom bridge network: ${NETWORK_NAME} ==="
docker network rm "${NETWORK_NAME}" 2>/dev/null || true

echo "=== Verifying removal ==="
docker ps -a --filter "name=flask" --filter "name=mysql" --filter "name=redis"
docker network ls --filter "name=${NETWORK_NAME}"

echo "Cleanup completed successfully."
