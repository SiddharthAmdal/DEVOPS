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
- [ ] **Phase 2: Service Exposure & Traffic Routing (NodePort)**
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
