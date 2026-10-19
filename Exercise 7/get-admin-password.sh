#!/usr/bin/env bash
# ==============================================================================
# Script to Retrieve Jenkins Initial Admin Password
# Exercise 7: Introduction to CI and Jenkins Installation
# ==============================================================================

set -euo pipefail

CONTAINER_NAME="jenkins"

if ! docker ps --format '{{.Names}}' | grep -Eq "^${CONTAINER_NAME}\$"; then
    echo "Error: Container '${CONTAINER_NAME}' is not running."
    echo "Start Jenkins with: ./'Exercise 7'/install-jenkins.sh"
    exit 1
fi

echo "Retrieving Initial Administrator Password from container '${CONTAINER_NAME}'..."
PASSWORD=$(docker exec "${CONTAINER_NAME}" cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || true)

if [ -z "${PASSWORD}" ]; then
    echo "Password file not yet created or already completed initial setup."
    echo "If you have already set up a user account, use those credentials."
    exit 1
fi

echo "========================================================================"
echo " Jenkins Initial Admin Password:"
echo " ${PASSWORD}"
echo "========================================================================"
echo "Access the portal at: http://localhost:8080"
