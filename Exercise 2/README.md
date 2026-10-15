# Exercise 2: Deploy a Flask App on Minikube using kubectl and YAML

## Objective
Learn Kubernetes fundamentals by deploying a custom Python Flask web application on a local Minikube cluster using declarative YAML manifests. This exercise explores building container images directly inside Minikube's Docker daemon, understanding image pull policies (`imagePullPolicy: Never`), managing Kubernetes Deployments, and exposing internal container ports via a NodePort Service.

---

## Prerequisites & References
- **The Illustrated Children’s Guide to Kubernetes**: [CNCF Phippy Guide](https://www.cncf.io/phippy/the-childrens-illustrated-guide-to-kubernetes/)
- **Video Walkthrough**: [Watch on YouTube](https://www.youtube.com/watch?v=3I9PkvZ80BQ)
- **Origins of Kubernetes with Tim Hockin**: [Watch on YouTube](https://www.youtube.com/watch?v=xSztxKexDXM)
- **Kubernetes in its Second Decade (Tim Hockin)**: [Watch on YouTube](https://www.youtube.com/watch?v=WqeShpaztZY)
- **Minikube Documentation**: [Minikube Docs](https://minikube.sigs.k8s.io/docs/)

---

## Minikube Cheat Sheet (Frequently Used Commands)

| Category | Command | Description |
| :--- | :--- | :--- |
| **Cluster Lifecycle** | `minikube start` | Start Minikube with default driver/settings |
| | `minikube stop` | Stop cluster without deleting state |
| | `minikube delete` | Teardown and delete the cluster VM/container |
| **Status & Cluster Info** | `minikube status` | Check status of host, kubelet, and apiserver |
| | `kubectl cluster-info` | Display Kubernetes master control plane endpoints |
| **Service Access** | `minikube service <name>` | Open service in browser via tunnel |
| | `minikube service <name> --url` | Print routed external URL |
| | `minikube service list` | List all available service URLs |
| | `minikube tunnel` | Create network route for LoadBalancer services |
| **Docker Daemon Sync** | `eval $(minikube docker-env)` | Point host Docker CLI to Minikube's Docker daemon |
| | `minikube image load <image>` | Load pre-built local image directly into Minikube |
| **Logs & Dashboards** | `minikube dashboard` | Launch the official Kubernetes web dashboard |
| | `minikube logs` | View internal Minikube cluster logs |
| | `minikube ssh` | Open an interactive SSH session into Minikube |

---

## Exercise Implementation Roadmap

- [x] **Phase 1: Flask Application & Containerization**
  - Implement lightweight Python Flask app on port `15000` ([`app.py`](./app.py)).
  - Specify dependencies in [`requirements.txt`](./requirements.txt).
  - Create optimized Docker container specification ([`Dockerfile`](./Dockerfile) & [`.dockerignore`](./.dockerignore)).
- [ ] **Phase 2: Minikube Docker Daemon Build & Kubernetes Deployment**
  - Point Docker CLI to Minikube's Docker environment (`eval $(minikube docker-env)`).
  - Build local container image `flask-app:latest`.
  - Create declarative Deployment manifest with `imagePullPolicy: Never` ([`flask-deployment.yaml`](./flask-deployment.yaml)).
  - Deploy to cluster, verify replicas, inspect pods and logs, and demonstrate direct port 15000 access limitation.
- [ ] **Phase 3: Service Exposure (NodePort), End-to-End Routing & Automation**
  - Update [`flask-deployment.yaml`](./flask-deployment.yaml) with NodePort Service (`port: 15000`, `targetPort: 15000`).
  - Document port vs targetPort vs nodePort traffic translation.
  - Verify accessibility via Minikube tunnel and `curl`.
  - Provide automated build, deployment, and cleanup scripts.

---

## Phase 1: Flask Application & Containerization

### 1. Application Design (`app.py`)
The application is a simple, lightweight HTTP service built with Flask:
- **Port**: Listens on all interfaces (`0.0.0.0`) on port `15000`.
- **Endpoint**: Root path `/` returns `"Hello from Flask on Kubernetes!"`.

```python
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Hello from Flask on Kubernetes!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=15000)
```

### 2. Containerization (`Dockerfile`)
The container is built on top of `python:3.8-slim` to keep the image minimal and secure:
- Installs dependencies using `pip` without caching unnecessary tarballs (`--no-cache-dir`).
- Sets working directory to `/app`.
- Exposes port `15000`.
- Executes `python app.py` as container PID 1.
