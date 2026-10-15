# Exercise 3: Scaling Flask App on Single Node using ReplicaSets

## Real-Life Tech Use Case: E-Commerce Flash Sale
During a flash sale on an e-commerce platform (like Flipkart’s Big Billion Days or Amazon Prime Day), normal traffic of ~100 requests per minute can instantaneously spike to 10,000+ requests per minute.
* **The Single-Pod Bottleneck**: If the application runs as a solitary Pod, it will be overwhelmed by concurrent connections, experience severe latency spikes, and crash under the load.
* **The ReplicaSet Solution**: Kubernetes **ReplicaSets** ensure that a specified number of identical Pod clones are always running. When a flash sale commences, operators or autoscalers can scale out to 5, 10, or 20 Pods, distributing customer checkout requests evenly across identical replicas. When traffic subsides, the cluster scales back in to conserve resources.

---

## Core Learnings & Architectural Principles

1. **Pod Distribution**: Each Pod serves as an identical worker. Scaling horizontally means stamping out identical clones of the application container.
2. **Resiliency & Self-Healing**: If a Pod process crashes or the container is terminated, the ReplicaSet controller detects the discrepancy between *desired* and *actual* states and immediately spawns a replacement Pod.
3. **Efficiency**: Enables dynamic elasticity—allocating computing resources strictly when user demand surges, rather than paying for idle over-provisioned infrastructure.
4. **Traffic Inspection**: The application reports the hostname of the specific Pod that served each request (`socket.gethostname()`), allowing verification of load balancing across replicas.

---

## Exercise Implementation Roadmap

- [x] **Phase 1: Flash Sale Application & Containerization**
  - Implement Flask application with `/`, `/buy`, and `/health` endpoints tracking serving Pod hostnames ([`app.py`](./app.py)).
  - Configure production WSGI server dependencies ([`requirements.txt`](./requirements.txt)).
  - Build optimized Python 3.11 container specification ([`Dockerfile`](./Dockerfile) & [`.dockerignore`](./.dockerignore)).
- [ ] **Phase 2: ReplicaSet & Service Manifests, Initial Deployment & Cluster IP**
  - Create declarative ReplicaSet manifest with 3 replicas, readiness/liveness probes, and resource constraints ([`flashsale-replicaset.yaml`](./flashsale-replicaset.yaml)).
  - Build container image `flashsale:1.0` inside Minikube.
  - Deploy to cluster, verify 3 running pods and probes, and test traffic routing.
- [ ] **Phase 3: Dynamic Scaling, Self-Healing Resiliency, Q&A & Operational Scripts**
  - Scale ReplicaSet from 3 to 5 replicas (`kubectl scale rs`).
  - Demonstrate self-healing by deleting a live Pod and observing instant controller recovery.
  - Document pod node distribution and complete theoretical Q&A.
  - Provide automated build, deployment, scale, and cleanup scripts.

---

## Phase 1: Flash Sale Application & Containerization

### 1. Application Endpoints (`app.py`)
The application simulates an e-commerce flash sale service:
* **`GET /`**: Welcome banner returning the serving Pod hostname and server timestamp.
* **`GET /buy`**: Simulates a customer checkout order, selecting a random item (Smartphone, Shoes, Headphones, Laptop) or taking a `?user=` query parameter, returning `served_by_pod`.
* **`GET /health`**: Health endpoint returning `{"status": "healthy", "pod": ...}` designed for Kubernetes Liveness and Readiness probes.

```python
from flask import Flask, request
import socket, time, random

app = Flask(__name__)

@app.get("/")
def homepage():
    return {
        "message": "Welcome to Big Sale!",
        "pod": socket.gethostname(),
        "ts": time.time()
    }

@app.get("/buy")
def buy():
    item = random.choice(["Smartphone", "Shoes", "Headphones", "Laptop"])
    user = request.args.get("user", f"user{random.randint(1,1000)}")
    return {
        "status": "success",
        "item": item,
        "user": user,
        "served_by_pod": socket.gethostname(),
        "time": time.strftime("%H:%M:%S")
    }

@app.get("/health")
def health():
    return {"status": "healthy", "pod": socket.gethostname()}
```

### 2. WSGI Server & Container Configuration (`Dockerfile`)
* **Base Image**: `python:3.11-slim` ensures minimal image footprint and hardened attack surface.
* **WSGI Production Server**: Uses `gunicorn` with 1 worker and 2 threads (`gunicorn -b 0.0.0.0:5000 app:app --workers 1 --threads 2`).
* **Port**: Listens on port `5000`.
