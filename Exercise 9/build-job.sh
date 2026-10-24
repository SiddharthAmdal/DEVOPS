#!/usr/bin/env bash
# ==============================================================================
# Script to Trigger Build and Inspect Console Output for 'Python-MultiStage-Pipeline'
# Exercise 9: Jenkins Multi-Stage Pipeline Exercise
# ==============================================================================

set -euo pipefail

JOB_NAME="Python-MultiStage-Pipeline"
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
COOKIE_JAR="/tmp/jenkins_pipeline_cookies"

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

# Record current build number before triggering
PREV_BUILD=$(curl -s -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/job/${JOB_NAME}/lastBuild/api/json" 2>/dev/null | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("number", 0))
except:
    print(0)
')

echo "=== [3/4] Triggering Pipeline Build for '${JOB_NAME}' ==="
TRIGGER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" \
  -H "${CRUMB_FIELD}:${CRUMB}" \
  "${JENKINS_URL}/job/${JOB_NAME}/build")

if [ "${TRIGGER_STATUS}" == "201" ] || [ "${TRIGGER_STATUS}" == "200" ]; then
    echo "Pipeline build triggered successfully (HTTP ${TRIGGER_STATUS})."
else
    echo "Failed to trigger build (HTTP ${TRIGGER_STATUS})."
    exit 1
fi

echo "Waiting for build execution to start and finish..."
COUNTER=0
MAX_WAIT=45
BUILD_NUM=""
RESULT=""

while true; do
    BUILD_INFO=$(curl -s -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/job/${JOB_NAME}/lastBuild/api/json" 2>/dev/null || true)
    CURRENT_NUM=$(echo "${BUILD_INFO}" | python3 -c '
import sys, json
try:
    print(json.load(sys.stdin).get("number", 0))
except:
    print(0)
')
    
    # Check if a new build has started
    if [ "${CURRENT_NUM}" -gt "${PREV_BUILD}" ]; then
        BUILDING=$(echo "${BUILD_INFO}" | python3 -c '
import sys, json
try:
    print("true" if json.load(sys.stdin).get("building") else "false")
except:
    print("true")
')
        if [ "${BUILDING}" == "false" ]; then
            BUILD_NUM="${CURRENT_NUM}"
            RESULT=$(echo "${BUILD_INFO}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("result", "UNKNOWN"))')
            echo -e "\nBuild #${BUILD_NUM} finished with status: ${RESULT}"
            break
        fi
    fi

    COUNTER=$((COUNTER + 1))
    if [ "${COUNTER}" -ge "${MAX_WAIT}" ]; then
        echo -e "\nTimed out waiting for pipeline completion."
        BUILD_NUM="${CURRENT_NUM}"
        break
    fi
    echo -ne "Pipeline running... (${COUNTER}/${MAX_WAIT}s)\r"
    sleep 2
done

echo ""
echo "=== [4/4] Live Console Output for Build #${BUILD_NUM:-1} ==="
echo "------------------------------------------------------------------------"
curl -s -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/job/${JOB_NAME}/lastBuild/consoleText" || true
echo "------------------------------------------------------------------------"

# Clean up cookie jar
rm -f "${COOKIE_JAR}"
