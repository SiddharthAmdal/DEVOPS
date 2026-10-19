#!/usr/bin/env bash
# ==============================================================================
# Jenkins Docker Installation and Deployment Script
# Exercise 7: Introduction to CI and Jenkins Installation
# ==============================================================================

set -euo pipefail

CONTAINER_NAME="jenkins"
IMAGE_NAME="jenkins/jenkins:lts"
VOLUME_NAME="jenkins_home"
HTTP_PORT="8080"
AGENT_PORT="50000"

echo "=== [1/4] Checking for Existing Jenkins Containers ==="
if docker ps -a --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "Existing container '${CONTAINER_NAME}' found. Removing it to start fresh..."
    docker rm -f "${CONTAINER_NAME}"
fi

echo "=== [2/4] Launching Jenkins Container (${IMAGE_NAME}) ==="
echo "Port mappings: ${HTTP_PORT} (Web UI), ${AGENT_PORT} (Agent JNLP)"
echo "Persistent Volume: ${VOLUME_NAME} -> /var/jenkins_home"

docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HTTP_PORT}:8080" \
  -p "${AGENT_PORT}:50000" \
  -v "${VOLUME_NAME}:/var/jenkins_home" \
  "${IMAGE_NAME}"

echo ""
echo "=== [3/4] Waiting for Jenkins Initialization ==="
echo "Jenkins is starting up and generating initial credentials..."

# Loop until initialAdminPassword is generated and HTTP 200/403 is reachable
MAX_RETRIES=40
COUNTER=0

until docker exec "${CONTAINER_NAME}" test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; do
    COUNTER=$((COUNTER + 1))
    if [ "${COUNTER}" -ge "${MAX_RETRIES}" ]; then
        echo "Timed out waiting for initialAdminPassword to be generated."
        exit 1
    fi
    echo -ne "Initializing Jenkins... (${COUNTER}/${MAX_RETRIES}s)\r"
    sleep 2
done
echo ""

echo "=== [4/4] Jenkins is Ready! ==="
PASSWORD=$(docker exec "${CONTAINER_NAME}" cat /var/jenkins_home/secrets/initialAdminPassword)

echo "========================================================================"
echo " Jenkins Initial Administrator Password:"
echo " ${PASSWORD}"
echo "========================================================================"
echo ""
echo "Web Management Dashboard: http://localhost:${HTTP_PORT}"
echo "To view this password again at any time, run:"
echo "  ./'Exercise 7'/get-admin-password.sh"
echo "To tear down Jenkins, run:"
echo "  ./'Exercise 7'/cleanup.sh"
