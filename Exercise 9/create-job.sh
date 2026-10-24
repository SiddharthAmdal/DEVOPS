#!/usr/bin/env bash
# ==============================================================================
# Script to Create or Update the 'Python-MultiStage-Pipeline' Jenkins Job
# Exercise 9: Jenkins Multi-Stage Pipeline Exercise
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_XML="${SCRIPT_DIR}/job_config.xml"
JOB_NAME="Python-MultiStage-Pipeline"
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
COOKIE_JAR="/tmp/jenkins_pipeline_cookies"

echo "=== [1/4] Checking Jenkins Container & Extracting Credentials ==="
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

echo "=== [3/4] Creating or Updating Pipeline Job '${JOB_NAME}' ==="
CHECK_JOB=$(curl -s -o /dev/null -w "%{http_code}" -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/job/${JOB_NAME}/api/json" || true)

if [ "${CHECK_JOB}" == "200" ]; then
    echo "Job '${JOB_NAME}' already exists. Updating pipeline configuration..."
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
    echo "Creating new pipeline job '${JOB_NAME}'..."
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
echo "Pipeline Job URL: ${JENKINS_URL}/job/${JOB_NAME}"
echo "To trigger the pipeline, run: ./'Exercise 9'/build-job.sh"
