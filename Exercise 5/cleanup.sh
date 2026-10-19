#!/usr/bin/env bash
# ==============================================================================
# Teardown and Cleanup Script for Exercise 5 (Docker Security with AppArmor)
# ==============================================================================

set -euo pipefail

echo "=== [1/2] Stopping and Removing Exercise 5 Containers ==="
for CONTAINER_NAME in "flask-apparmor-instance" "flask-apparmor-test" "flask-secure"; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
        echo "Removing container: ${CONTAINER_NAME}..."
        docker rm -f "${CONTAINER_NAME}" || true
    fi
done

echo "=== [2/2] Optional Image Cleanup ==="
echo "To clean up the built Docker image, run:"
echo "  docker rmi flask-apparmor"

echo ""
echo "=== Cleanup completed successfully ==="
