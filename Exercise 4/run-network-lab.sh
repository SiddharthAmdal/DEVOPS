#!/usr/bin/env bash
# ==============================================================================
# Docker Multi-Container Networking Lab Automation
# Exercise 4: Docker Networking with Multiple Containers
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="my-bridge-net"

echo "=== [1/5] Creating Custom Bridge Network: ${NETWORK_NAME} ==="
if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    docker network create --driver bridge "${NETWORK_NAME}"
    echo "Network ${NETWORK_NAME} created."
else
    echo "Network ${NETWORK_NAME} already exists."
fi

echo "=== [2/5] Building Flask API Image ==="
docker build -t flask-api "${SCRIPT_DIR}"

echo "=== [3/5] Starting Multi-Tier Containers on ${NETWORK_NAME} ==="
# Remove any leftover containers with matching names
docker rm -f mysql redis flask 2>/dev/null || true

# Start MySQL
echo "Starting MySQL..."
docker run -d --name mysql --net="${NETWORK_NAME}" -e MYSQL_ROOT_PASSWORD=root mysql:latest

# Start Redis
echo "Starting Redis..."
docker run -d --name redis --net="${NETWORK_NAME}" redis:latest

# Start Flask Web App
echo "Starting Flask API on port 5001..."
docker run -d --name flask --net="${NETWORK_NAME}" -p 5001:5001 flask-api

echo "=== [4/5] Verifying Active Containers ==="
docker ps --filter "name=flask" --filter "name=mysql" --filter "name=redis" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== [5/5] Testing Inter-Container DNS Connectivity & Web API ==="
echo "--- Testing Ping from 'flask' to 'mysql' container ---"
docker exec flask ping -c 3 mysql

echo ""
echo "--- Testing Ping from 'flask' to 'redis' container ---"
docker exec flask ping -c 3 redis

echo ""
echo "--- Testing Host HTTP Endpoint Access ---"
curl -s -i http://localhost:5001/about

echo ""
echo "=== Lab Completed Successfully! ==="
echo "To clean up all containers and network, run: ./'Exercise 4/cleanup.sh'"
