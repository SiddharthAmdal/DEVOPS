# Exercise 2: Deploy a Flask App on Minikube using kubectl and YAML

> 🔗 **Original Lab Exercise**: [2-Minikube-Kubectl-Flask.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/2-Minikube-Kubectl-Flask.md)

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
- [x] **Phase 2: Minikube Docker Daemon Build & Kubernetes Deployment**
  - Point Docker CLI to Minikube's Docker environment (`eval $(minikube docker-env)`).
  - Build local container image `flask-app:latest`.
  - Create declarative Deployment manifest with `imagePullPolicy: Never` ([`flask-deployment.yaml`](./flask-deployment.yaml)).
  - Deploy to cluster, verify replicas, inspect pods and logs, and demonstrate direct port 15000 access limitation.
- [x] **Phase 3: Service Exposure (NodePort), End-to-End Routing & Automation**
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

---

## Phase 2: Minikube Docker Daemon Build & Kubernetes Deployment

### 1. Building the Docker Image Inside Minikube
By default, Docker commands run against your host system's Docker daemon. To make images available to Minikube without pushing them to a public registry (Docker Hub), we configure the Docker CLI to talk to Minikube's internal Docker daemon:

Display environment variables:
```bash
minikube docker-env
```

Apply the environment variables and build the image:
```bash
eval $(minikube docker-env)
docker build -t flask-app:latest "Exercise 2"
```

*(Alternative command using Minikube's built-in builder):*
```bash
minikube image build -t flask-app:latest "Exercise 2"
```

---

### 2. Understanding Kubernetes `imagePullPolicy`
Kubernetes provides three image pull policies in container specifications:

| Policy | Behavior | Best Used For |
| :--- | :--- | :--- |
| **`Always`** | Kubelet queries remote registry on every pod creation and forces a pull. | Production environments with mutable tags (e.g. `:latest`). |
| **`IfNotPresent`** | Kubelet pulls the image only if it is not already cached on the node. | Production deployments with immutable/semantic version tags. |
| **`Never`** | Kubelet never queries a remote registry; fails immediately with `ErrImageNeverPull` if not cached locally. | Local development with images built directly inside Minikube. |

By configuring `imagePullPolicy: Never` in [`flask-deployment.yaml`](./flask-deployment.yaml), we instruct Kubernetes to use the local `flask-app:latest` image and prevent it from trying to search Docker Hub.

---

### 3. Deploying the Application

Apply the declarative Deployment manifest:
```bash
kubectl apply -f "Exercise 2/flask-deployment.yaml"
```

---

### 4. Verifying Deployment & Runtime State

#### Check Deployment Status
```bash
kubectl get deployments
```
Expected output:
```text
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
flask-app   1/1     1            1           15s
```

#### Check Created Pods
```bash
kubectl get pods -l app=flask-app
```
Expected output:
```text
NAME                         READY   STATUS    RESTARTS   AGE
flask-app-7d8b5bc8b9-x2k4l   1/1     Running   0          20s
```

#### Inspect Detailed Deployment Metadata & Events
```bash
kubectl describe deployment flask-app
```

#### Inspect Application Logs
```bash
kubectl logs -l app=flask-app
```
Expected output:
```text
 * Serving Flask app 'app'
 * Debug mode: off
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:15000
 * Running on http://10.244.0.4:15000
Press CTRL+C to quit
```

---

### 5. Demonstrating Network Isolation: The Missing Service

Check existing services:
```bash
kubectl get services
```
Notice that only the default cluster API service exists:
```text
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   1d
```

Now attempt to reach the Flask application from your host:
```bash
curl http://127.0.0.1:15000
```
Result:
```text
curl: (7) Failed to connect to 127.0.0.1 port 15000 after 1 ms: Couldn't connect to server
```

#### Why Does Direct Access Fail?
1. **Isolated Container Namespace**: The Flask app runs inside an isolated Linux network namespace inside the Minikube cluster node.
2. **Ephemeral Cluster IP**: The Pod is assigned a private cluster IP (e.g., `10.244.0.4`), which is not routable directly from the macOS host network.
3. **No External Route**: Without a Kubernetes **Service** (such as `NodePort`), no ingress point exists to forward incoming host traffic into the target container port `15000`.

---

## Phase 3: Service Exposure (NodePort), End-to-End Routing & Automation

### 1. Updated Manifest (`flask-deployment.yaml`)
To bridge the isolation boundary, a `NodePort` Service is declared alongside the Deployment in [`flask-deployment.yaml`](./flask-deployment.yaml):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app
  labels:
    app: flask-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
        - name: flask-app
          image: flask-app:latest
          imagePullPolicy: Never
          ports:
            - containerPort: 15000
---
apiVersion: v1
kind: Service
metadata:
  name: flask-app-service
  labels:
    app: flask-app
spec:
  type: NodePort
  selector:
    app: flask-app
  ports:
    - name: http
      protocol: TCP
      port: 15000
      targetPort: 15000
```

---

### 2. Traffic Flow & Port Mapping Architecture

```
+-----------------------------------------------------------------------------------+
| Host System (macOS / WSL)                                                         |
| Client Request: curl http://127.0.0.1:<allocated-tunnel-port>                    |
+-----------------------------------------------------------------------------------+
                                       |
                                       v
+-----------------------------------------------------------------------------------+
| Minikube Node (Virtual Environment / Docker Bridge)                              |
| NodePort: 3xxxx (Dynamically allocated in range 30000-32767)                      |
|                                                                                   |
|                                       v                                           |
| Service: flask-app-service (ClusterIP: 10.x.x.x)                                 |
| port: 15000 (Internal virtual port exposed by Kubernetes Service)                |
|                                                                                   |
|                                       v (kube-proxy DNAT via iptables)            |
| Pod: flask-app-xxxxxx (CNI IP: 10.244.0.x)                                       |
| targetPort: 15000 (Port listened to by Flask application inside container)       |
+-----------------------------------------------------------------------------------+
```

#### Key Definitions:
* **`port: 15000` (Service Port)**: The port exposed by the Kubernetes Service inside the cluster network.
* **`targetPort: 15000` (Container Port)**: The port on which the Flask server is listening inside the container (`0.0.0.0:15000`).
* **`nodePort` (Node Port)**: The port opened across all cluster nodes (in range 30000–32767) that proxies external traffic into the Service.

---

### 3. Applying the Manifest

Deploy the updated manifest:
```bash
kubectl apply -f "Exercise 2/flask-deployment.yaml"
```
Expected output:
```text
deployment.apps/flask-app unchanged
service/flask-app-service created
```

Verify the service and active endpoints:
```bash
kubectl get service flask-app-service
kubectl get endpoints flask-app-service
```
Expected output:
```text
NAME                TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
flask-app-service   NodePort   10.104.22.45    <none>        15000:31254/TCP   10s

NAME                ENDPOINTS          AGE
flask-app-service   10.244.0.4:15000   10s
```

---

### 4. Accessing the Application

#### Method 1: Using Minikube Service URL (Recommended)
Generate the reachable URL via Minikube tunnel:
```bash
minikube service flask-app-service --url
```
Example output:
```text
http://127.0.0.1:54321
! Because you are using a Docker driver on darwin, the terminal needs to be open to run it.
```

In a separate terminal, test access using `curl`:
```bash
curl http://127.0.0.1:54321
```
Expected response:
```text
Hello from Flask on Kubernetes!
```

#### Method 2: Local Port-Forwarding
Forward local port `15000` directly to the service:
```bash
kubectl port-forward service/flask-app-service 15000:15000
```
Then visit `http://localhost:15000` or curl directly:
```bash
curl http://localhost:15000
```

---

### 5. Automation Helper Scripts

#### Automated Build & Deploy
Builds image inside Minikube, applies manifest, waits for rollout, and outputs endpoints:
```bash
./"Exercise 2/build-and-deploy.sh"
```

#### Automated Teardown
Deletes deployment and service cleanly:
```bash
./"Exercise 2/cleanup.sh"
```

---

### 6. DevOps Troubleshooting Matrix

| Symptom | Root Cause | Diagnosis | Fix |
| :--- | :--- | :--- | :--- |
| **`ErrImageNeverPull`** | Image not built in Minikube's Docker daemon | `kubectl describe pod -l app=flask-app` | Run `eval $(minikube docker-env)` before `docker build` or use `minikube image build`. |
| **`CrashLoopBackOff`** | Python error or missing dependency in container | `kubectl logs -l app=flask-app` | Inspect Python traceback; check `requirements.txt`. |
| **Endpoints `<none>`** | Service selector does not match Pod labels | `kubectl get endpoints flask-app-service` | Verify `spec.selector` in Service matches `spec.template.metadata.labels` in Deployment. |
| **Connection Refused on URL** | Flask bound only to `127.0.0.1` inside container | Inspect `app.py` | Ensure `app.run(host='0.0.0.0', port=15000)` is specified. |


