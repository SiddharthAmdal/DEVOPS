#!/usr/bin/env bash
# ==============================================================================
# Teardown and Cleanup Script for Exercise 6 (Monitoring Stack)
# ==============================================================================

set -euo pipefail

echo "=== [1/2] Stopping and Removing Monitoring Stack Containers ==="
for CONTAINER in "delivery_metrics" "prometheus" "grafana" "jenkins"; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER}\$"; then
        echo "Removing container: ${CONTAINER}..."
        docker rm -f "${CONTAINER}" || true
    fi
done

echo "=== [2/2] Optional Image and Volume Cleanup ==="
echo "To clean up the built application image, run:"
echo "  docker rmi delivery_metrics"
echo ""
echo "=== Cleanup completed successfully ==="
