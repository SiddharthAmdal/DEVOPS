#!/usr/bin/env bash
# ==============================================================================
# Teardown and Cleanup Script for Exercise 8 ('HelloWorld' Job)
# ==============================================================================

set -euo pipefail

JOB_NAME="HelloWorld"
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
COOKIE_JAR="/tmp/jenkins_cookies"

echo "=== [1/2] Removing 'HelloWorld' Job from Jenkins ==="
if docker ps --format '{{.Names}}' | grep -Eq "^jenkins\$"; then
    ADMIN_PASS=$(docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || true)
    if [ -n "${ADMIN_PASS}" ]; then
        CRUMB_JSON=$(curl -s -c "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" "${JENKINS_URL}/crumbIssuer/api/json" || true)
        CRUMB=$(echo "${CRUMB_JSON}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("crumb", ""))' 2>/dev/null || true)
        CRUMB_FIELD=$(echo "${CRUMB_JSON}" | python3 -c 'import sys, json; print(json.load(sys.stdin).get("crumbRequestField", ""))' 2>/dev/null || true)

        if [ -n "${CRUMB}" ]; then
            curl -s -X POST -b "${COOKIE_JAR}" -u "${ADMIN_USER}:${ADMIN_PASS}" \
              -H "${CRUMB_FIELD}:${CRUMB}" \
              "${JENKINS_URL}/job/${JOB_NAME}/doDelete" || true
            echo "Job '${JOB_NAME}' deleted from Jenkins."
        fi
        rm -f "${COOKIE_JAR}"
    fi
else
    echo "Jenkins container is not running."
fi

echo "=== [2/2] Cleanup Completed ==="
echo "The job definition and scripts in Exercise 8 remain preserved in version control."
