#!/usr/bin/env bash
# ==============================================================================
# Setup and Run AppArmor Lab
# Exercise 5: Docker Security with AppArmor and Python
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_NAME="my-apparmor-profile"
IMAGE_NAME="flask-apparmor"

echo "=== [1/4] Checking AppArmor System Support ==="
if command -v apparmor_parser >/dev/null 2>&1; then
    echo "Found apparmor_parser. Loading ${PROFILE_NAME}..."
    if [ "$EUID" -eq 0 ]; then
        cp "${SCRIPT_DIR}/${PROFILE_NAME}" "/etc/apparmor.d/${PROFILE_NAME}"
        apparmor_parser -r "/etc/apparmor.d/${PROFILE_NAME}"
        echo "Profile ${PROFILE_NAME} loaded successfully."
    else
        echo "Note: Run 'sudo apparmor_parser -r ${SCRIPT_DIR}/${PROFILE_NAME}' with root privileges on Linux hosts."
    fi
else
    echo "Note: apparmor_parser is native to Linux kernels."
fi

echo "=== [2/4] Building Docker Image: ${IMAGE_NAME} ==="
docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

echo "=== [3/4] Running AppArmor Application Script ==="
python3 "${SCRIPT_DIR}/apply_apparmor.py" || true

echo "=== [4/4] Running Restricted Actions Test ==="
python3 "${SCRIPT_DIR}/test_restricted_actions.py" || true

echo ""
echo "=== Lab Execution Completed ==="
