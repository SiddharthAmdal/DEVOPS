#!/usr/bin/env bash
# ==============================================================================
# Alert Simulation Script for Exercise 6 (ZAPPTTO Delivery Monitoring)
# ==============================================================================

set -euo pipefail

MODE="${1:-trigger}"

if [ "$MODE" == "--restore" ] || [ "$MODE" == "restore" ]; then
    echo "=== [1/2] Restoring Standard Delivery Simulation (pending 10-20) ==="
    docker rm -f delivery_metrics 2>/dev/null || true
    docker run -d --name delivery_metrics -p 8000:8000 -e "SIMULATE_HIGH_ALERTS=false" delivery_metrics
    echo "Standard simulation restored. Metrics back in normal range."
    exit 0
fi

echo "=== [1/3] Triggering High Alert Simulation (pending deliveries: 50-100) ==="
docker rm -f delivery_metrics 2>/dev/null || true
docker run -d --name delivery_metrics -p 8000:8000 -e "SIMULATE_HIGH_ALERTS=true" delivery_metrics

echo ""
echo "=== [2/3] Waiting 16s for Prometheus Evaluation Interval (rule: for 15s) ==="
for i in {16..1}; do
    echo -ne "Evaluating rule threshold... ${i}s remaining\r"
    sleep 1
done
echo ""

echo "=== [3/3] Checking Alert Status in Prometheus ==="
python3 -c '
import urllib.request, json
try:
    req = urllib.request.urlopen("http://localhost:9090/api/v1/alerts")
    data = json.loads(req.read().decode())
    alerts = data["data"]["alerts"]
    if not alerts:
        print("No active alerts yet. Rule might still be evaluating.")
    for a in alerts:
        name = a["labels"].get("alertname")
        state = a.get("state")
        active_since = a.get("activeAt")
        value = a.get("value")
        print(f"🚨 Alert: {name} | State: {state.upper()} | Value: {value} | Since: {active_since}")
except Exception as e:
    print(f"Error querying Prometheus API: {e}")
'

echo ""
echo "View active alerts in Prometheus UI: http://localhost:9090/alerts"
echo "To restore normal simulation, run: ./Exercise\ 6/simulate-alerts.sh --restore"
