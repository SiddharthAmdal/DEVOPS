#!/usr/bin/env bash
# ==============================================================================
# Connectivity Fault Injection and Diagnosis Script
# DevOps CIE: Question 3 (Task 8)
# ==============================================================================

set -euo pipefail

NETWORK_NAME="food-delivery-net"
FLASK_CONTAINER="flask-order-service"
REDIS_CONTAINER="redis"
APP_PORT="5001"

echo "========================================================================"
echo "TASK 8: Deliberate Connectivity Fault Injection & Diagnostic Walkthrough"
echo "========================================================================"

echo ""
echo "=== Step 1: Baseline Health Check (Pre-Fault) ==="
echo "Testing http://localhost:${APP_PORT}/health..."
curl -s "http://localhost:${APP_PORT}/health" | python3 -m json.tool

echo ""
echo "=== Step 2: Deliberately Introducing Fault ==="
echo "Action: Disconnecting container '${REDIS_CONTAINER}' from '${NETWORK_NAME}'..."
docker network disconnect "${NETWORK_NAME}" "${REDIS_CONTAINER}"
echo "✓ Fault injected: '${REDIS_CONTAINER}' is now isolated from the application network."

echo ""
echo "=== Step 3: Triggering Application Traffic under Fault Condition ==="
echo "Querying http://localhost:${APP_PORT}/health..."
HTTP_CODE=$(curl -s -o /tmp/fault_health_resp.json -w "%{http_code}" "http://localhost:${APP_PORT}/health" || true)
echo "HTTP Response Code: ${HTTP_CODE} (Expected 503 / Degraded)"
cat /tmp/fault_health_resp.json | python3 -m json.tool

echo ""
echo "=== Step 4: Diagnostic Inspection - Container Logs ==="
echo "Executing: docker logs --tail 15 ${FLASK_CONTAINER}"
echo "------------------------------------------------------------------------"
docker logs --tail 15 "${FLASK_CONTAINER}"
echo "------------------------------------------------------------------------"
echo "🔍 DIAGNOSTIC FINDING (Logs):"
echo "   The Flask container logged an error connecting to 'redis:6379'."
echo "   DNS or network routing to hostname 'redis' has failed."

echo ""
echo "=== Step 5: Diagnostic Inspection - Docker Network Configuration ==="
echo "Executing: docker network inspect ${NETWORK_NAME}"
echo "------------------------------------------------------------------------"
docker network inspect "${NETWORK_NAME}" --format '{{json .Containers}}' | python3 -m json.tool
echo "------------------------------------------------------------------------"
echo "🔍 DIAGNOSTIC FINDING (Network Configuration):"
echo "   Notice that only 'mysql' and '${FLASK_CONTAINER}' are listed in ${NETWORK_NAME}."
echo "   '${REDIS_CONTAINER}' is completely missing from the bridge network container table!"

echo ""
echo "=== Step 6: Verifying In-Container DNS Failure ==="
echo "Testing DNS resolution from '${FLASK_CONTAINER}' to '${REDIS_CONTAINER}'..."
if docker exec "${FLASK_CONTAINER}" python3 -c "import socket; print(socket.gethostbyname('${REDIS_CONTAINER}'))" 2>&1; then
    echo "Resolution succeeded unexpectedly."
else
    echo "✓ DNS Resolution failed as expected: hostname '${REDIS_CONTAINER}' cannot be resolved by embedded DNS."
fi

##echo ""
##echo "=== Step 7: Incident Remediation ==="
##echo "Action: Reconnecting '${REDIS_CONTAINER}' to '${NETWORK_NAME}'..."
##docker network connect "${NETWORK_NAME}" "${REDIS_CONTAINER}"
##echo "✓ Remediation applied: '${REDIS_CONTAINER}' reconnected to '${NETWORK_NAME}'."

##echo ""
##echo "=== Step 8: Post-Remediation Verification ==="
##echo "Verifying network members:"
##docker network inspect "${NETWORK_NAME}" --format '{{range .Containers}}{{.Name}} -> {{.IPv4Address}}{{"\n"}}{{end}}'

##echo ""
##echo "Retesting in-container DNS resolution:"
##docker exec "${FLASK_CONTAINER}" python3 -c "import socket; print('Resolved redis -> ' + socket.gethostbyname('${REDIS_CONTAINER}'))"

##echo ""
##echo "Retesting health endpoint (http://localhost:${APP_PORT}/health):"
##curl -s "http://localhost:${APP_PORT}/health" | python3 -m json.tool

##echo ""
##echo "========================================================================"
##echo "Task 8 Diagnosis & Remediation Completed Successfully!"
##echo "========================================================================"
