#!/usr/bin/env bash
# ==============================================================================
# Script to Install Python 3 and Dependencies inside Jenkins Container
# Exercise 9: Handling Container Dependencies (Step 8)
# ==============================================================================

set -euo pipefail

echo "=== [1/2] Checking Jenkins Container ==="
if ! docker ps --format '{{.Names}}' | grep -Eq "^jenkins\$"; then
    echo "Error: Container 'jenkins' is not running."
    echo "Start it with: docker start jenkins"
    exit 1
fi

echo "=== [2/2] Installing python3, pip, venv, and flask inside 'jenkins' ==="
docker exec -u root jenkins bash -c "
    apt-get update && \
    apt-get install -y python3 python3-pip python3-venv python3-flask && \
    python3 --version && \
    pip --version
"

echo "=== Dependencies Installed Successfully ==="
