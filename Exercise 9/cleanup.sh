#!/usr/bin/env bash
# ==============================================================================
# Script to Clean Up Exercise 9 Pipeline Job & Test Deployment
# Exercise 9: Jenkins Multi-Stage Pipeline Exercise
# ==============================================================================

set -euo pipefail

JOB_NAME="Python-MultiStage-Pipeline"
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
COOKIE_JAR="/tmp/jenkins_pipeline_cookies"

echo "=== [1/2] Stopping Background Flask App in Workspace (if running) ==="
if docker ps --format '{{.Names}}' | grep -Eq "^jenkins\$"; then
    docker exec jenkins bash -c '
    PID_FILE="/var/jenkins_home/workspace/Python-MultiStage-Pipeline/python-app-deploy/app.pid"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        echo "Found running Flask app (PID $PID). Killing..."
        kill -9 "$PID" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi
    ' || true
fi

echo "=== [2/2] Deleting Jenkins Pipeline Job '${JOB_NAME}' ==="
if docker ps --format '{{.Names}}' | grep -Eq "^jenkins\$"; then
    ADMIN_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword)
    CRUMB_JSON=$(curl -s -c "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/crumbIssuer/api/json")
    CRUMB=$(echo "${CRUMB_JSON}" | python3 -c 'import sys, json; print(json.load(sys.stdin)["crumb"])')
    CRUMB_FIELD=$(echo "${CRUMB_JSON}" | python3 -c 'import sys, json; print(json.load(sys.stdin)["crumbRequestField"])')

    DEL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" \
      -H "${CRUMB_FIELD}:${CRUMB}" \
      "${JENKINS_URL}/job/${JOB_NAME}/doDelete" || true)

    if [ "${DEL_STATUS}" == "200" ] || [ "${DEL_STATUS}" == "302" ]; then
        echo "Job '${JOB_NAME}' removed successfully."
    else
        echo "Delete returned status: ${DEL_STATUS} (Job may not exist)."
    fi
    rm -f "${COOKIE_JAR}"
fi

echo "Cleanup completed."
