#!/usr/bin/env bash
# ==============================================================================
# Script to Create or Update the 'HelloWorld' Jenkins Job
# Exercise 8: Creating "Hello World" Jenkins Job
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_XML="${SCRIPT_DIR}/job_config.xml"
JOB_NAME="HelloWorld"
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
COOKIE_JAR="/tmp/jenkins_cookies"

echo "=== [1/4] Retrieving Admin Password from Jenkins Container ==="
if ! docker ps --format '{{.Names}}' | grep -Eq "^jenkins\$"; then
    echo "Error: Container 'jenkins' is not running."
    echo "Start it with: docker start jenkins"
    exit 1
fi

ADMIN_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Password retrieved successfully."

echo "=== [2/4] Fetching CSRF Crumb & Session Cookie ==="
CRUMB_JSON=$(curl -s -c "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/crumbIssuer/api/json")
CRUMB=$(echo "${CRUMB_JSON}" | python3 -c 'import sys, json; print(json.load(sys.stdin)["crumb"])')
CRUMB_FIELD=$(echo "${CRUMB_JSON}" | python3 -c 'import sys, json; print(json.load(sys.stdin)["crumbRequestField"])')
echo "Obtained CSRF Crumb (${CRUMB_FIELD})."

echo "=== [3/4] Creating/Updating Job '${JOB_NAME}' ==="
CHECK_JOB=$(curl -s -o /dev/null -w "%{http_code}" -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/job/${JOB_NAME}/api/json" || true)

if [ "${CHECK_JOB}" == "200" ]; then
    echo "Job '${JOB_NAME}' already exists. Updating configuration..."
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" \
      -H "${CRUMB_FIELD}:${CRUMB}" \
      -H "Content-Type: application/xml" \
      --data-binary "@${CONFIG_XML}" \
      "${JENKINS_URL}/job/${JOB_NAME}/config.xml")
    if [ "${STATUS}" == "200" ]; then
        echo "Job '${JOB_NAME}' configuration updated successfully."
    else
        echo "Update returned HTTP ${STATUS}."
    fi
else
    echo "Creating new job '${JOB_NAME}'..."
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" \
      -H "${CRUMB_FIELD}:${CRUMB}" \
      -H "Content-Type: application/xml" \
      --data-binary "@${CONFIG_XML}" \
      "${JENKINS_URL}/createItem?name=${JOB_NAME}")
    if [ "${STATUS}" == "200" ]; then
        echo "Job '${JOB_NAME}' created successfully."
    else
        echo "Creation returned HTTP ${STATUS}."
    fi
fi

# Clean up cookie jar
rm -f "${COOKIE_JAR}"

echo ""
echo "=== [4/4] Verification ==="
echo "Job URL: ${JENKINS_URL}/job/${JOB_NAME}"
echo "To trigger the build now, run: ./'Exercise 8'/build-job.sh or click 'Build Now' in Jenkins UI."
