#!/usr/bin/env bash
# ==============================================================================
# Complete Orchestration Runner for Exercise 6 (Monitoring Stack)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITORING_DIR="${SCRIPT_DIR}/delivery_monitoring"

echo "=== [1/4] Building delivery_metrics Docker Image ==="
docker build -t delivery_metrics "${MONITORING_DIR}"

echo "=== [2/4] Starting delivery_metrics Service (Port 8000) ==="
docker rm -f delivery_metrics 2>/dev/null || true
docker run -d --name delivery_metrics -p 8000:8000 delivery_metrics

echo "=== [3/4] Starting Prometheus Monitoring (Port 9090) ==="
docker rm -f prometheus 2>/dev/null || true
docker run -d --name prometheus -p 9090:9090 \
  -v "${MONITORING_DIR}/prometheus.yml":/etc/prometheus/prometheus.yml \
  -v "${MONITORING_DIR}/alert_rules.yml":/etc/prometheus/alert_rules.yml \
  prom/prometheus

echo "=== [4/4] Starting Grafana Visualization (Port 3000) ==="
docker rm -f grafana 2>/dev/null || true
docker run -d --name grafana -p 3000:3000 \
  -e "GF_SECURITY_ADMIN_USER=admin" \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  -e "GF_USERS_ALLOW_SIGN_UP=false" \
  -v "${MONITORING_DIR}/grafana/provisioning":/etc/grafana/provisioning \
  grafana/grafana

echo ""
echo "=== ZAPPTTO Monitoring Stack Active ==="
echo "Metrics Endpoint:   http://localhost:8000/metrics"
echo "Prometheus Web UI:  http://localhost:9090 (Targets: http://localhost:9090/targets)"
echo "Prometheus Alerts:  http://localhost:9090/alerts"
echo "Grafana Dashboard:  http://localhost:3000/d/zapptto-delivery-dash/zzappto-dashboard (Login: admin / admin)"
echo ""
echo "To test alert triggering, run: ./'Exercise 6'/simulate-alerts.sh"
echo "To tear down the stack, run:    ./'Exercise 6'/cleanup.sh"
