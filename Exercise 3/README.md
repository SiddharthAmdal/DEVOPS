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
- [x] **Phase 2: ReplicaSet & Service Manifests, Initial Deployment & Cluster IP**
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

---

## Phase 2: ReplicaSet & Service Manifests, Initial Deployment & Cluster IP

### 1. Understanding the Kubernetes ReplicaSet
A **ReplicaSet**'s purpose is to maintain a stable set of replica Pods running at any given time.
* **Reconciliation Loop**: Compares the *desired state* (`spec.replicas: 3`) with the *current state* in the cluster.
* **Label Selector**: Finds matching Pods via `matchLabels: { app: flashsale }`. Any Pod carrying this label is counted towards the desired replica target.
* **Pod Template**: Defines the blueprint (`spec.template`) used to stamp out identical clones whenever actual count < desired count.

---

### 2. Building the Image in Minikube's Docker Daemon
Ensure the image is built directly into Minikube's local container store:

```bash
eval $(minikube docker-env)
docker build -t flashsale:1.0 "Exercise 3"
```
*(Or using Minikube's native builder):*
```bash
minikube image build -t flashsale:1.0 "Exercise 3"
```

---

### 3. Declarative Manifest Breakdown (`flashsale-replicaset.yaml`)

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: flashsale-rs
  labels:
    app: flashsale
spec:
  replicas: 3
  selector:
    matchLabels:
      app: flashsale
  template:
    metadata:
      labels:
        app: flashsale
    spec:
      containers:
      - name: flashsale-container
        image: flashsale:1.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5000
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 2
          periodSeconds: 5
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 10
          periodSeconds: 10
        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "500m"
            memory: "256Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: flashsale-svc
  labels:
    app: flashsale
spec:
  selector:
    app: flashsale
  ports:
  - name: http
    port: 80
    targetPort: 5000
  type: ClusterIP
```

#### Key Architecture Elements:
* **Readiness Probe**: Queries `GET /health` every 5 seconds. Kubernetes will **not** route customer traffic to a pod until this probe passes.
* **Liveness Probe**: Monitors process vitality. If the Flask server deadlocks or crashes, kubelet terminates and restarts the container.
* **Resource Boundaries**: Requests `100m` CPU / `128Mi` RAM and limits to `500m` CPU / `256Mi` RAM to prevent any single replica from starving the node.
* **ClusterIP Service**: Acts as an internal load balancer on port `80`, forwarding requests to port `5000` across all healthy replicas.

---

### 4. Deploying & Inspecting the Initial 3 Replicas

Apply the manifest:
```bash
kubectl apply -f "Exercise 3/flashsale-replicaset.yaml"
```
Expected output:
```text
replicaset.apps/flashsale-rs created
service/flashsale-svc created
```

Check the ReplicaSet status:
```bash
kubectl get rs flashsale-rs
```
Expected output:
```text
NAME           DESIRED   CURRENT   READY   AGE
flashsale-rs   3         3         3       15s
```

Check all 3 Pod clones:
```bash
kubectl get pods -l app=flashsale -o wide
```
Expected output:
```text
NAME                 READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
flashsale-rs-8gbfp   1/1     Running   0          20s   10.244.0.5    minikube   <none>           <none>
flashsale-rs-f4gsl   1/1     Running   0          20s   10.244.0.6    minikube   <none>           <none>
flashsale-rs-nb5kl   1/1     Running   0          20s   10.244.0.7    minikube   <none>           <none>
```

Verify that all 3 Pod IPs are registered under the Service Endpoints:
```bash
kubectl get endpoints flashsale-svc
```
Expected output:
```text
NAME            ENDPOINTS                                      AGE
flashsale-svc   10.244.0.5:5000,10.244.0.6:5000,10.244.0.7:5000   30s
```

---

### 5. Verifying Load Distribution Across Pods
Forward local port `8080` to the internal Service:
```bash
kubectl port-forward service/flashsale-svc 8080:80
```

Execute multiple checkout requests:
```bash
curl "http://localhost:8080/buy?user=customer42"
curl "http://localhost:8080/buy?user=customer42"
curl "http://localhost:8080/buy?user=customer42"
```

Notice that the `served_by_pod` value rotates across your active replicas:
```json
{"item":"Laptop","served_by_pod":"flashsale-rs-8gbfp","status":"success","time":"12:20:15","user":"customer42"}
{"item":"Smartphone","served_by_pod":"flashsale-rs-f4gsl","status":"success","time":"12:20:16","user":"customer42"}
{"item":"Shoes","served_by_pod":"flashsale-rs-nb5kl","status":"success","time":"12:20:17","user":"customer42"}
```

