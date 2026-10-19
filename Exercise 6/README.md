# Exercise 6: Real-Time Operations Monitoring and Alerting

## Objective
As a DevOps engineer at **ZAPPTTO** managing an ultra-fast on-demand delivery service, you need real-time operational insights into delivery performance, order backlogs, and latency bottlenecks.

In this exercise, you will design, containerize, and deploy a complete production-grade monitoring and alerting stack utilizing:
1. **Python (`prometheus_client`)**: To instrument and expose real-time delivery operations metrics (`total_deliveries`, `pending_deliveries`, `on_the_way_deliveries`, `average_delivery_time`) on HTTP endpoint `/metrics`.
2. **Prometheus**: To scrape operational metrics at regular intervals, evaluate metric expressions, and trigger automated alerts based on configured threshold rules.
3. **Grafana**: To visualize metrics across interactive real-time dashboards with specialized graphs for delivery status and service duration.
4. **Jenkins**: To automate the build, containerization, and orchestration lifecycle through a declarative CI/CD pipeline (`Jenkinsfile`).

---

## Architectural Telemetry Workflow

```
+-----------------------------------------------------------------------------------+
|                              ZAPPTTO Delivery Platform                            |
+-----------------------------------------------------------------------------------+
                                          |
                                          | 1. Exposes metrics on :8000/metrics
                                          v
                    +------------------------------------------+
                    |  Python Delivery Service & Simulation    |
                    |      (delivery_metrics.py on :8000)      |
                    +------------------------------------------+
                                          |
                      2. Periodic Scrapes | (Every 15s HTTP GET)
                                          v
                    +------------------------------------------+
                    |             Prometheus Server            |
                    |                 (Port 9090)              |
                    |  * Scrape Targets: :8000, :9090          |
                    |  * Rule Evaluation (alert_rules.yml)     |
                    +------------------------------------------+
                           /                              \
       3. Queries PromQL  /                                \ 4. Fires Alerts
                         v                                  v
+-------------------------------+             +----------------------------------+
|       Grafana Dashboards      |             |         Alert Evaluation         |
|          (Port 3000)          |             |   * HighPendingDeliveries        |
|  * Total Deliveries           |             |   * HighAverageDeliveryTime      |
|  * Pending Deliveries         |             +----------------------------------+
|  * On-The-Way Deliveries      |
|  * Average Delivery Duration  |
+-------------------------------+
                                 ^
                                 | 5. Automated Build & Deploy
+-----------------------------------------------------------------------------------+
|                         Jenkins Automation Pipeline (Port 8080)                   |
|   [Pre-check Docker] -> [Setup Workspace] -> [Build Image] -> [Deploy Services]   |
+-----------------------------------------------------------------------------------+
```

---

## Exercise Implementation Roadmap

- [x] **Phase 1: Metrics Instrumentation, Python Simulation & Containerization**
  - Establish `delivery_monitoring/` directory structure.
  - Define dependencies in [`requirements.txt`](./delivery_monitoring/requirements.txt).
  - Implement delivery metrics simulation engine ([`delivery_metrics.py`](./delivery_monitoring/delivery_metrics.py)) using `prometheus_client`.
  - Instrument metrics: `total_deliveries` (Gauge), `pending_deliveries` (Gauge), `on_the_way_deliveries` (Gauge), and `average_delivery_time` (Summary).
  - Create container specification ([`Dockerfile`](./delivery_monitoring/Dockerfile) & [`.dockerignore`](./delivery_monitoring/.dockerignore)).
  - Build and verify Docker image `delivery_metrics`.

- [x] **Phase 2: Prometheus Scraping, Alerting Rules & Grafana Dashboard Provisioning**
  - Configure Prometheus scraping targets ([`prometheus.yml`](./delivery_monitoring/prometheus.yml)).
  - Define operational alerting rules ([`alert_rules.yml`](./delivery_monitoring/alert_rules.yml)) for `HighPendingDeliveries` and `HighAverageDeliveryTime`.
  - Set up Grafana data source configuration and auto-provisioned dashboards with the 4 delivery monitoring panels.
  - Orchestrate Prometheus and Grafana container services.

- [x] **Phase 3: Jenkins CI/CD Pipeline, Alert Simulation & End-to-End Verification**
  - Construct declarative pipeline script ([`Jenkinsfile`](./delivery_monitoring/Jenkinsfile)) handling Docker pre-checks, workspace setup, image building, and multi-service deployment.
  - Implement alert simulation mode to trigger and verify active alert firing in Prometheus and Grafana.
  - Provide operational runner scripts ([`run-monitoring.sh`](./run-monitoring.sh), [`cleanup.sh`](./cleanup.sh)).
  - Conduct full live verification and capture dashboard telemetry.

---

## Phase 1: Metrics Instrumentation, Python Simulation & Containerization

### 1. Prometheus Metric Types Overview

Prometheus supports four fundamental core metric types:

| Metric Type | Characteristics | Use Case in ZAPPTTO |
| :--- | :--- | :--- |
| **Gauge** | Numerical value that can arbitrarily go up or down. Represents a instantaneous snapshot. | `total_deliveries`, `pending_deliveries`, `on_the_way_deliveries` |
| **Summary** | Samples observations (typically request durations or response sizes) and calculates configurable quantiles over a sliding time window. Also provides `_sum` and `_count`. | `average_delivery_time` (seconds taken per completed order) |
| **Counter** | Cumulative metric that represents a single monotonically increasing counter whose value can only increase or be reset to zero on restart. | Total completed orders, total HTTP requests, system errors |
| **Histogram** | Samples observations and counts them in configurable bucket intervals, providing `_bucket`, `_sum`, and `_count`. | Complex SLA latency distribution analysis |

---

### 2. Python Metric Simulation Engine (`delivery_metrics.py`)

The application simulates fluctuating order counts and delivery durations, updating Prometheus Gauges and Summaries every second:

```python
import os
import random
import time
from prometheus_client import start_http_server, Summary, Gauge

# Prometheus Metrics Definitions
total_deliveries = Gauge("total_deliveries", "Total number of deliveries")
pending_deliveries = Gauge("pending_deliveries", "Number of pending deliveries")
on_the_way_deliveries = Gauge("on_the_way_deliveries", "Number of deliveries on the way")
average_delivery_time = Summary("average_delivery_time", "Average delivery time in seconds")

def simulate_delivery():
    simulate_high_alerts = os.getenv("SIMULATE_HIGH_ALERTS", "false").lower() in ("true", "1", "yes")

    if simulate_high_alerts:
        pending = random.randint(50, 100)
    else:
        pending = random.randint(10, 20)

    on_the_way = random.randint(5, 20)
    delivered = random.randint(30, 70)
    avg_time = random.uniform(15, 45)

    total = pending + on_the_way + delivered

    print(f"[DEBUG] Total deliveries: {total}")
    print(f"[DEBUG] Pending deliveries: {pending}")
    print(f"[DEBUG] On-the-way deliveries: {on_the_way}")
    print(f"[DEBUG] Average delivery time: {avg_time:.2f} seconds")

    total_deliveries.set(total)
    pending_deliveries.set(pending)
    on_the_way_deliveries.set(on_the_way)
    average_delivery_time.observe(avg_time)

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    print(f"[INFO] Starting the HTTP server on port {port}...")
    start_http_server(port, addr="0.0.0.0")
    print(f"[INFO] HTTP server started. Simulating deliveries at http://0.0.0.0:{port}/metrics...")

    while True:
        simulate_delivery()
        print("[INFO] Sleeping for 1 seconds...")
        time.sleep(1)
```

---

### 3. Containerization Specification (`Dockerfile`)

```dockerfile
FROM python:3.10-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY delivery_metrics.py .

EXPOSE 8000

CMD ["python", "delivery_metrics.py"]
```

#### Build Command:
```bash
docker build -t delivery_metrics "Exercise 6/delivery_monitoring"
```

---

### 4. Running and Verifying Metrics Locally

Run the container in detached mode exposing port 8000:
```bash
docker run -d --name delivery_metrics -p 8000:8000 delivery_metrics
```

Inspect the Prometheus `/metrics` endpoint using `curl`:
```bash
curl http://localhost:8000/metrics
```

#### Sample Metrics Output:
```text
# HELP total_deliveries Total number of deliveries
# TYPE total_deliveries gauge
total_deliveries 68.0
# HELP pending_deliveries Number of pending deliveries
# TYPE pending_deliveries gauge
pending_deliveries 14.0
# HELP on_the_way_deliveries Number of deliveries on the way
# TYPE on_the_way_deliveries gauge
on_the_way_deliveries 12.0
# HELP average_delivery_time Average delivery time in seconds
# TYPE average_delivery_time summary
average_delivery_time_count 15.0
average_delivery_time_sum 423.85
```

---

## Phase 2: Prometheus Scraping, Alerting Rules & Grafana Dashboard Provisioning

### 1. Prometheus Scrape Configuration (`prometheus.yml`)

The Prometheus server is configured to scrape both itself and the ZAPPTTO delivery metrics service every 15 seconds:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - /etc/prometheus/alert_rules.yml

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "delivery_service"
    static_configs:
      - targets: ["172.17.0.1:8000"]
```

#### Key Architecture Notes:
* **`targets: ["172.17.0.1:8000"]`**: Maps to the host interface from inside Docker bridge networks. (On macOS Docker Desktop, `172.17.0.1` and `host.docker.internal` both cleanly route traffic to services on the host).
* **`rule_files`**: Directs Prometheus to parse and evaluate `/etc/prometheus/alert_rules.yml` every evaluation interval.

---

### 2. Operational Alerting Rules (`alert_rules.yml`)

Prometheus evaluates threshold rules against incoming delivery telemetry:

```yaml
groups:
  - name: delivery_alerts
    rules:
      - alert: HighPendingDeliveries
        expr: pending_deliveries > 10
        for: 15s
        labels:
          severity: warning
        annotations:
          summary: "High pending deliveries"
          description: "Pending deliveries are above 10 for the last 15 second."

      - alert: HighAverageDeliveryTime
        expr: (average_delivery_time_sum / average_delivery_time_count) > 30
        for: 15s
        labels:
          severity: critical
        annotations:
          summary: "High average delivery time"
          description: "Average delivery time is above 30 seconds for the last 15 seconds."
```

#### Rule Logic:
1. **`HighPendingDeliveries`**: If the backlog of orders awaiting courier assignment exceeds `10` continuously for `15s`, a `warning` alert transitions from `PENDING` $\rightarrow$ `FIRING`.
2. **`HighAverageDeliveryTime`**: Computed via `average_delivery_time_sum / average_delivery_time_count` (the mathematical average of all delivery durations observed). If latency exceeds `30` seconds, a `critical` alert fires.

---

### 3. Launching Prometheus

Start the Prometheus container with volumes mounted:
```bash
docker run -d --name prometheus -p 9090:9090 \
  -v "$(pwd)/Exercise 6/delivery_monitoring/prometheus.yml":/etc/prometheus/prometheus.yml \
  -v "$(pwd)/Exercise 6/delivery_monitoring/alert_rules.yml":/etc/prometheus/alert_rules.yml \
  prom/prometheus
```

Verify targets at [http://localhost:9090/targets](http://localhost:9090/targets):
* `delivery_service`: State **UP** (`http://172.17.0.1:8000/metrics`)
* `prometheus`: State **UP** (`http://localhost:9090/metrics`)

---

### 4. Grafana Visualizations & Automated Provisioning

To avoid tedious manual setup, Grafana is configured with automated file-based provisioning in [`grafana/provisioning/`](./delivery_monitoring/grafana/provisioning/):

1. **Datasource Provisioning** (`datasources/prometheus.yml`):
   Automatically binds Prometheus at `http://172.17.0.1:9090` as the default datasource.
2. **Dashboard Provisioning** (`dashboards/dashboards.yml` & `dashboards/zapptto-delivery-dashboard.json`):
   Auto-creates the **ZZAPPTO Dashboard** with 4 interactive panels:
   * **Panel 1: `pending_deliveries`** $\rightarrow$ PromQL: `pending_deliveries`
   * **Panel 2: `OnTheWayDeliveries`** $\rightarrow$ PromQL: `on_the_way_deliveries`
   * **Panel 3: `total_deliveries`** $\rightarrow$ PromQL: `total_deliveries`
   * **Panel 4: `AverageDeliveryTime`** $\rightarrow$ PromQL: `average_delivery_time_sum / average_delivery_time_count`

#### Launch Command:
```bash
docker run -d --name grafana -p 3000:3000 \
  -e "GF_SECURITY_ADMIN_USER=admin" \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  -e "GF_USERS_ALLOW_SIGN_UP=false" \
  -v "$(pwd)/Exercise 6/delivery_monitoring/grafana/provisioning":/etc/grafana/provisioning \
  grafana/grafana
```

Access Grafana at [http://localhost:3000](http://localhost:3000) (Credentials: `admin` / `admin`).
Navigate to **Dashboards** $\rightarrow$ **Operations** $\rightarrow$ **ZZAPPTO Dashboard** ([http://localhost:3000/d/zapptto-delivery-dash/zzappto-dashboard](http://localhost:3000/d/zapptto-delivery-dash/zzappto-dashboard)).

---

## Phase 3: Jenkins CI/CD Pipeline, Alert Simulation & End-to-End Verification

### 1. Declarative Jenkins Pipeline (`Jenkinsfile`)

The [`delivery_monitoring/Jenkinsfile`](./delivery_monitoring/Jenkinsfile) orchestrates the entire continuous deployment and monitoring lifecycle through 5 distinct stages:

```groovy
pipeline {
    agent any

    environment {
        APP_IMAGE = 'delivery_metrics'
        CONTAINER_APP = 'delivery_metrics'
        CONTAINER_PROM = 'prometheus'
        CONTAINER_GRAFANA = 'grafana'
    }

    stages {
        stage('Pre-check Docker') {
            steps {
                script {
                    def dockerVersion = sh(script: 'docker --version', returnStdout: true).trim()
                    if (!dockerVersion) {
                        error "Docker is not installed or not in the PATH."
                    }
                    def dockerInfo = sh(script: 'docker info', returnStatus: true)
                    if (dockerInfo != 0) {
                        error "Docker daemon is not running."
                    }
                    echo "Docker is available: ${dockerVersion}"
                }
            }
        }

        stage('Setup Workspace') {
            steps {
                echo "Validating workspace configuration files..."
                sh 'ls -la'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building delivery_metrics image..."
                sh 'docker build -t ${APP_IMAGE} .'
            }
        }

        stage('Run Application') {
            steps {
                echo "Deploying delivery_metrics container..."
                sh '''
                    docker rm -f ${CONTAINER_APP} 2>/dev/null || true
                    docker run -d -p 8000:8000 --name ${CONTAINER_APP} ${APP_IMAGE}
                '''
            }
        }

        stage('Run Prometheus & Grafana') {
            steps {
                echo "Deploying Prometheus and Grafana..."
                sh '''
                    docker rm -f ${CONTAINER_PROM} ${CONTAINER_GRAFANA} 2>/dev/null || true
                    docker run -d --name ${CONTAINER_PROM} -p 9090:9090 \
                        -v $WORKSPACE/prometheus.yml:/etc/prometheus/prometheus.yml \
                        -v $WORKSPACE/alert_rules.yml:/etc/prometheus/alert_rules.yml \
                        prom/prometheus
                    docker run -d --name ${CONTAINER_GRAFANA} -p 3000:3000 grafana/grafana
                '''
            }
        }
    }
}
```

#### Running Jenkins in Docker:
```bash
# 1. Start Jenkins LTS container
docker run -d --name jenkins -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts

# 2. Retrieve initial admin password
docker exec -it jenkins cat /var/jenkins_home/secrets/initialAdminPassword

# 3. Access Jenkins web UI
open http://localhost:8080
```
In Jenkins, select **New Item** $\rightarrow$ **Pipeline**, and paste the pipeline script into the definition block to execute.

---

### 2. Alert Simulation & Threshold Verification

To test incident response and verify Prometheus rule evaluation, [`simulate-alerts.sh`](./simulate-alerts.sh) triggers elevated pending deliveries:

```bash
# Trigger High Alert Mode (pending deliveries: 50 - 100)
./"Exercise 6/simulate-alerts.sh"
```

#### Incident Progression:
1. `pending_deliveries` immediately jumps into the 50–100 range (exceeding threshold `> 10`).
2. **0s – 15s (`PENDING` state)**: Prometheus flags the alert condition as pending to prevent false positives from transient spikes.
3. **> 15s (`FIRING` state)**: The rule duration timer expires; `HighPendingDeliveries` transitions to **`FIRING`** in bright red in the Prometheus Alerts UI.

#### Querying Active Alerts via API:
```bash
curl -s http://localhost:9090/api/v1/alerts | python3 -m json.tool
```
```text
🚨 Alert: HighPendingDeliveries | State: FIRING | Value: 7.8e+01
🚨 Alert: HighAverageDeliveryTime | State: PENDING | Value: 3.69e+01
```

To restore the simulation back to standard baseline (pending deliveries 10–20):
```bash
./"Exercise 6/simulate-alerts.sh" --restore
```

---

### 3. Operational Automation Scripts

| Script | Purpose | Usage |
| :--- | :--- | :--- |
| **[`run-monitoring.sh`](./run-monitoring.sh)** | Builds image and spins up `delivery_metrics`, `prometheus`, and `grafana` with pre-provisioned dashboards. | `./"Exercise 6/run-monitoring.sh"` |
| **[`simulate-alerts.sh`](./simulate-alerts.sh)** | Simulates traffic spikes (`50-100` pending) to trigger alerts, or restores baseline (`--restore`). | `./"Exercise 6/simulate-alerts.sh"` |
| **[`cleanup.sh`](./cleanup.sh)** | Stops and removes all monitoring containers cleanly (`delivery_metrics`, `prometheus`, `grafana`, `jenkins`). | `./"Exercise 6/cleanup.sh"` |

---

### 4. Verification Summary Matrix

| Service | Target Port | Status | Verification Check |
| :--- | :---: | :---: | :--- |
| **Delivery Metrics Service** | `8000` | **UP** | `curl http://localhost:8000/metrics` returns `total_deliveries`, `pending_deliveries`, `on_the_way_deliveries`, `average_delivery_time` |
| **Prometheus Server** | `9090` | **UP** | [http://localhost:9090/targets](http://localhost:9090/targets) shows `delivery_service` (1/1 UP) and `prometheus` (1/1 UP) |
| **Prometheus Alerting** | `9090` | **UP** | [http://localhost:9090/alerts](http://localhost:9090/alerts) validates `HighPendingDeliveries` transitioning to `FIRING` |
| **Grafana Dashboard** | `3000` | **UP** | [http://localhost:3000/d/zapptto-delivery-dash/zzappto-dashboard](http://localhost:3000/d/zapptto-delivery-dash/zzappto-dashboard) renders all 4 time-series panels |
| **Jenkins Pipeline** | `8080` | **READY** | Declarative `Jenkinsfile` ready for CI/CD multi-stage automation |


