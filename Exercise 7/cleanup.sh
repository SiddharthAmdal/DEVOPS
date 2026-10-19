#!/usr/bin/env bash
# ==============================================================================
# Teardown and Cleanup Script for Exercise 7 (Jenkins)
# ==============================================================================

set -euo pipefail

CONTAINER_NAME="jenkins"
VOLUME_NAME="jenkins_home"

echo "=== [1/2] Stopping and Removing Jenkins Container ==="
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "Stopping and removing container: ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}"
    echo "Container removed."
else
    echo "Container '${CONTAINER_NAME}' does not exist."
fi

echo "=== [2/2] Optional Volume Cleanup ==="
if [ "${1:-}" == "--all" ] || [ "${1:-}" == "-v" ]; then
    echo "Removing persistent Docker volume: ${VOLUME_NAME}..."
    docker volume rm "${VOLUME_NAME}" 2>/dev/null || true
    echo "Volume ${VOLUME_NAME} removed."
else
    echo "Note: The persistent volume '${VOLUME_NAME}' was preserved."
    echo "To completely delete all Jenkins data, run: ./'Exercise 7'/cleanup.sh --all"
fi

echo ""
echo "=== Cleanup completed successfully ==="
