#!/usr/bin/env bash
# ==============================================================================
# Scale Flash Sale ReplicaSet
# Exercise 3: Scaling Flask App on Single Node using ReplicaSets
# ==============================================================================

set -euo pipefail

TARGET_REPLICAS="${1:-5}"
RS_NAME="flashsale-rs"

echo "=== Scaling ReplicaSet '${RS_NAME}' to ${TARGET_REPLICAS} replicas ==="
kubectl scale rs "${RS_NAME}" --replicas="${TARGET_REPLICAS}"

echo "=== Waiting for Pods to be Ready ==="
kubectl wait --for=condition=Ready pod -l app=flashsale --timeout=60s

echo "=== ReplicaSet Status ==="
kubectl get rs "${RS_NAME}"

echo "=== Active Pod Distribution ==="
kubectl get pods -l app=flashsale -o wide

echo ""
echo "Successfully scaled to ${TARGET_REPLICAS} replicas!"
