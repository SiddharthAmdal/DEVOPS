#!/usr/bin/env bash
# ==============================================================================
# Script to Trigger Build and Inspect Console Output for 'HelloWorld'
# Exercise 8: Creating "Hello World" Jenkins Job
# ==============================================================================

set -euo pipefail

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

echo "=== [3/4] Triggering Build Now for '${JOB_NAME}' ==="
TRIGGER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -H "${CRUMB_FIELD}:${CRUMB}" \
  "${JENKINS_URL}/job/${JOB_NAME}/build")

if [ "${TRIGGER_STATUS}" == "201" ] || [ "${TRIGGER_STATUS}" == "200" ]; then
    echo "Build triggered successfully (HTTP ${TRIGGER_STATUS})."
else
    echo "Failed to trigger build (HTTP ${TRIGGER_STATUS})."
    exit 1
fi

echo "Waiting for build execution to finish..."
# Poll until build completes
COUNTER=0
MAX_WAIT=30
while true; do
    BUILD_INFO=$(curl -s -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/job/${JOB_NAME}/lastBuild/api/json" 2>/dev/null || true)
    BUILDING=$(echo "${BUILD_INFO}" | python3 -c 'import sys, json
try:
    data = json.load(sys.stdin)
    print("true" if data.get("building") else "false")
except:
    print("pending")
')
    if [ "${BUILDING}" == "false" ]; then
        BUILD_NUM=$(echo "${BUILD_INFO}" | python3 -c 'import sys, json; print(json.load(sys.stdin)["number"])')
        RESULT=$(echo "${BUILD_INFO}" | python3 -c 'import sys, json; print(json.load(sys.stdin)["result"])')
        echo "Build #${BUILD_NUM} finished with status: ${RESULT}"
        break
    fi
    COUNTER=$((COUNTER + 1))
    if [ "${COUNTER}" -ge "${MAX_WAIT}" ]; then
        echo "Timed out waiting for build completion."
        break
    fi
    echo -ne "Executing build... (${COUNTER}/${MAX_WAIT}s)\r"
    sleep 2
done
echo ""

echo "=== [4/4] Console Output for Build #${BUILD_NUM:-1} ==="
echo "------------------------------------------------------------------------"
curl -s -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/job/${JOB_NAME}/lastBuild/consoleText"
echo "------------------------------------------------------------------------"

# Clean up cookie jar
rm -f "${COOKIE_JAR}"
