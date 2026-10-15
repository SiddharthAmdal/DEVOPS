# Exercise 1: Hello Pod (Zepto Storefront Deployment)

## Business Problem
At **Zepto**, the product engineering team built a lightweight web app that renders the customer-facing storefront and live delivery tracking status. As a DevOps Engineer, your mission is to deploy this containerized application onto Kubernetes so that it is continuously available, portable, and ready for horizontal scaling.

In this introductory exercise, we simulate the storefront web application using the official `nginx` container image.

---

## Exercise Implementation Roadmap

- [x] **Phase 1: Pod Definition & Deployment**
  - Setup local cluster prerequisites (Minikube / Docker).
  - Define declarative Pod manifest (`pod.yaml`).
  - Deploy and verify Pod runtime status using `kubectl`.
- [x] **Phase 2: Service Exposure & Traffic Routing (NodePort)**
  - Expose the running Pod to external traffic using a NodePort Service.
  - Verify network routing and browse the Zepto storefront.
- [ ] **Phase 3: System Internals & Lifecycle Deep Dive**
  - Document the 8-stage Kubernetes control plane and worker node lifecycle (API Server, etcd, Scheduler, Kubelet, CRI, CNI).
  - Provide automated helper scripts for deployment validation and teardown.

---

## Phase 1: Pod Definition & Deployment

### 1. Prerequisites Setup
Ensure a container runtime (Docker Desktop / OrbStack / Colima) and Minikube are installed.

On macOS (via Homebrew):
```bash
brew install minikube
```

Verify tools:
```bash
kubectl version --client
minikube version
```

Start your local Kubernetes cluster:
```bash
minikube start --driver=docker
```

---

### 2. Deploying the Storefront Pod

#### Option A: Declarative Deployment (Recommended - Infrastructure as Code)
Deploy using the included [`pod.yaml`](./pod.yaml):
```bash
kubectl apply -f "Exercise 1/pod.yaml"
```

#### Option B: Imperative Command (Quick CLI run)
```bash
kubectl run hello-k8s --image=nginx --port=80
```

---

### 3. Verification & Inspection

Check that the Pod is up and transitioning to the `Running` state:
```bash
kubectl get pods -o wide
```

Inspect detailed container state, events, and assigned IP:
```bash
kubectl describe pod hello-k8s
```

View application logs:
```bash
kubectl logs hello-k8s
```

---

## Phase 2: Service Exposure & Traffic Routing (NodePort)

### 1. Why a Kubernetes Service?
In Kubernetes, Pods are ephemeral by design. When a Pod crashes or is rescheduled, its internal IP address changes. A **Service** acts as an abstraction layer with a stable IP, DNS name, and load balancer that automatically routes traffic to the Pods matching its label selector (`app: hello-k8s`).

For this exercise, we use a `NodePort` service, which opens an external port on every worker node in the cluster, forwarding incoming requests to port `80` of the Nginx container.

---

### 2. Exposing the Pod

#### Option A: Declarative Service (Recommended)
Deploy the service using [`service.yaml`](./service.yaml):
```bash
kubectl apply -f "Exercise 1/service.yaml"
```

#### Option B: Imperative Command
Expose the existing Pod directly via `kubectl`:
```bash
kubectl expose pod hello-k8s --type=NodePort --port=80
```

---

### 3. Verifying the Service & Endpoints

Inspect the created Service:
```bash
kubectl get services -o wide
```

Verify that the Service has registered the Pod's internal IP address under its `Endpoints`:
```bash
kubectl get endpoints hello-k8s
```

View detailed configuration (including assigned NodePort in range 30000–32767):
```bash
kubectl describe service hello-k8s
```

---

### 4. Accessing the Zepto Storefront

#### Method 1: Using Minikube Service Tunnel (Direct Browser Launch)
Launch the browser automatically or fetch the dynamically routed URL:
```bash
minikube service hello-k8s
```
To print only the accessible URL:
```bash
minikube service hello-k8s --url
```

#### Method 2: Port-Forwarding (Universal Local Access)
You can forward local port `8080` directly to the service:
```bash
kubectl port-forward service/hello-k8s 8080:80
```
Then visit `http://localhost:8080` in your web browser or test with `curl`:
```bash
curl -I http://localhost:8080
```
Expected output:
```http
HTTP/1.1 200 OK
Server: nginx/...
Content-Type: text/html
```

