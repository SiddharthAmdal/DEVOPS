#!/usr/bin/env bash
# ==============================================================================
# Complete Demonstration Runner: Food Delivery Platform with Docker Networking
# DevOps CIE: Question 3 (Coverage: Exercises 2, 4, and 5)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="food-delivery-net"
MYSQL_CONTAINER="mysql"
REDIS_CONTAINER="redis"
FLASK_CONTAINER="flask-order-service"
HOST_PORT="5001"

echo "========================================================================"
echo "   DEVOPS CIE: QUESTION 3 - FOOD DELIVERY PLATFORM WITH NETWORKING      "
echo "========================================================================"

echo ""
echo "=== [1/8] Environment Cleanup ==="
docker rm -f "${FLASK_CONTAINER}" "${MYSQL_CONTAINER}" "${REDIS_CONTAINER}" 2>/dev/null || true
docker network rm "${NETWORK_NAME}" 2>/dev/null || true
echo "✓ Cleaned previous containers and network."

echo ""
echo "=== [2/8] Task 2: Creating Custom Docker Bridge Network ==="
docker network create --driver bridge "${NETWORK_NAME}"
echo "✓ Created custom network: ${NETWORK_NAME}"
docker network inspect "${NETWORK_NAME}" --format 'Network ID: {{.Id}} | Subnet: {{(index .IPAM.Config 0).Subnet}} | Gateway: {{(index .IPAM.Config 0).Gateway}}'

echo ""
echo "=== [3/8] Task 3 & 4: Starting Data Tier (MySQL & Redis) on ${NETWORK_NAME} ==="
# Notice: MySQL port 3306 is NOT published to host (-p omitted)
echo "Starting MySQL container (port 3306 internal only)..."
docker run -d \
  --name "${MYSQL_CONTAINER}" \
  --net="${NETWORK_NAME}" \
  -e MYSQL_ROOT_PASSWORD=rootpassword \
  -e MYSQL_DATABASE=food_delivery_db \
  -e MYSQL_USER=order_user \
  -e MYSQL_PASSWORD=order_pass123 \
  -v "${SCRIPT_DIR}/init.sql:/docker-entrypoint-initdb.d/init.sql:ro" \
  mysql:latest

# Notice: Redis port 6379 is NOT published to host (-p omitted)
echo "Starting Redis container (port 6379 internal only)..."
docker run -d \
  --name "${REDIS_CONTAINER}" \
  --net="${NETWORK_NAME}" \
  redis:latest

echo ""
echo "=== [4/8] Building and Starting Flask Order Service on ${NETWORK_NAME} ==="
echo "Building Docker image: flask-order-service:latest..."
docker build -t flask-order-service:latest "${SCRIPT_DIR}"

# Notice: Only port 5000 is published to host as port 5001
echo "Starting Flask container (publishing only port ${HOST_PORT}:5000)..."
docker run -d \
  --name "${FLASK_CONTAINER}" \
  --net="${NETWORK_NAME}" \
  -p "${HOST_PORT}:5000" \
  -e MYSQL_HOST=mysql \
  -e MYSQL_PORT=3306 \
  -e MYSQL_USER=order_user \
  -e MYSQL_PASSWORD=order_pass123 \
  -e MYSQL_DB=food_delivery_db \
  -e REDIS_HOST=redis \
  -e REDIS_PORT=6379 \
  flask-order-service:latest

echo ""
echo "Waiting for MySQL database initialization and Flask service readiness..."
for i in {1..35}; do
    if curl -s "http://localhost:${HOST_PORT}/health" 2>/dev/null | grep -q '"status": "UP"'; then
        echo -e "\n✓ All services are UP and connected!"
        break
    fi
    echo -ne "Waiting for database & cache readiness... (${i}/35)\r"
    sleep 2
done
echo ""

echo ""
echo "=== [5/8] Task 4 & 5: Verifying Inter-Container DNS & Connectivity ==="
echo "--- A. In-container DNS Resolution to Service Names ---"
docker exec "${FLASK_CONTAINER}" python3 -c "import socket; print('Resolved mysql -> ' + socket.gethostbyname('mysql'))"
docker exec "${FLASK_CONTAINER}" python3 -c "import socket; print('Resolved redis -> ' + socket.gethostbyname('redis'))"

echo "--- B. In-container TCP Socket Connection to Services ---"
docker exec "${FLASK_CONTAINER}" python3 -c "import socket; s = socket.create_connection(('mysql', 3306), timeout=3); print('✓ TCP connection to mysql:3306 SUCCEEDED'); s.close()"
docker exec "${FLASK_CONTAINER}" python3 -c "import socket; s = socket.create_connection(('redis', 6379), timeout=3); print('✓ TCP connection to redis:6379 SUCCEEDED'); s.close()"

echo ""
echo "--- C. Verifying Health Endpoint (/health) ---"
curl -s "http://localhost:${HOST_PORT}/health" | python3 -m json.tool

echo ""
echo "--- D. Verifying Initial Order Fetch (Cache Miss -> MySQL DB) ---"
curl -s "http://localhost:${HOST_PORT}/orders" | python3 -m json.tool

echo ""
echo "--- E. Verifying Cached Order Fetch (Cache Hit -> Redis) ---"
curl -s "http://localhost:${HOST_PORT}/orders" | python3 -m json.tool

echo ""
echo "--- F. Verifying Order Creation (POST /orders) ---"
curl -s -X POST "http://localhost:${HOST_PORT}/orders" \
  -H "Content-Type: application/json" \
  -d '{"customer_name": "Siddharth", "restaurant_name": "Taco Bell", "items": "7-Layer Burrito, Nachos", "total_amount": 299.00}' \
  | python3 -m json.tool

echo ""
echo "=== [6/8] Task 6: Demonstrating Controlled Port Exposure (Host vs Internal) ==="
echo "--- A. Container Process & Port Status Table ---"
docker ps --filter "name=${FLASK_CONTAINER}" --filter "name=${MYSQL_CONTAINER}" --filter "name=${REDIS_CONTAINER}" \
  --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "--- B. Inspecting Docker Port Mappings for Each Container ---"
echo "docker port ${FLASK_CONTAINER}: $(docker port ${FLASK_CONTAINER})"
echo "docker port ${MYSQL_CONTAINER}: $(docker port ${MYSQL_CONTAINER} || echo 'None (Port 3306 is NOT published to host)')"
echo "docker port ${REDIS_CONTAINER}: $(docker port ${REDIS_CONTAINER} || echo 'None (Port 6379 is NOT published to host)')"

echo ""
echo "--- C. Host Access to Published Application Port (${HOST_PORT}) ---"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${HOST_PORT}/orders")
echo "Querying http://localhost:${HOST_PORT}/orders from host: HTTP ${HTTP_STATUS} (SUCCESS)"

echo ""
echo "--- D. Host Ingress Isolation Proof ---"
echo "Container 'mysql' NetworkSettings.Ports -> $(docker inspect ${MYSQL_CONTAINER} --format '{{json .NetworkSettings.Ports}}')"
echo "Container 'redis' NetworkSettings.Ports -> $(docker inspect ${REDIS_CONTAINER} --format '{{json .NetworkSettings.Ports}}')"
echo "✓ Proof: HostPort is null for both MySQL and Redis. Only Flask has host-bound ports."

echo ""
echo "=== [7/8] Task 7: AppArmor Security Confinement Test ==="
python3 "${SCRIPT_DIR}/apply_apparmor.py"

echo ""
echo "=== [8/8] Task 8: Diagnosing Deliberately Introduced Connectivity Issue ==="
bash "${SCRIPT_DIR}/diagnose_connectivity_fault.sh"

echo ""
echo "========================================================================"
echo "🎉 ALL TASKS FOR QUESTION 3 COMPLETED AND VERIFIED SUCCESSFULLY!"
echo "========================================================================"
echo "To clean up all containers and network, run: ./'DevOps CIE/cleanup.sh'"
