# Exercise 10: Multi-Node Kubernetes Cluster with Multiple Applications and ReplicaSets

> 🔗 **Original Lab Exercise**: [10-Minikube-Multi-Node-Multi-App-Minikube-Deployment.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/10-Minikube-Multi-Node-Multi-App-Minikube-Deployment.md)

## Storyboard & Use Case
In a high-velocity e-commerce platform, two critical microservices form the backbone of customer checkout:
1. **Product Catalog (`product-catalog`)**: High-throughput browsing service displaying available products, prices, and inventory. Requires **2 replicas**.
2. **Shopping Cart (`shopping-cart`)**: Transaction-critical service managing active customer carts and checkout sessions. Requires **3 replicas**.

### The High Availability Challenge
Running multiple pod replicas on a single node provides process-level resilience (if a process crashes, Kubelet restarts it), but **zero infrastructure-level resilience** (if the underlying virtual or physical node crashes, all replicas fail simultaneously, causing complete downtime).

To guarantee enterprise-grade high availability and fault tolerance:
- We deploy a **3-node Kubernetes cluster** using Minikube (`devops-multinode`, `devops-multinode-m02`, `devops-multinode-m03`).
- We enforce strict **Pod Anti-Affinity** rules using `kubernetes.io/hostname` so that Kubernetes scheduler never places two replicas of the same service on the same node.
- If any node in the cluster goes offline, surviving nodes continue serving live traffic without user disruption.

---

## Architectural Workflow: Multi-Node Pod Distribution

```
+------------------------------------------------------------------------------------------------------------------+
|                                        3-Node Kubernetes Cluster (devops-multinode)                              |
+------------------------------------------------------------------------------------------------------------------+
|                                                        |                                                         |
|                                     Kube-Scheduler (Pod Anti-Affinity)                                           |
|                                                        |                                                         |
|         +-----------------------------+----------------+-----------------------------+                           |
|         |                                              |                             |                           |
|         v                                              v                             v                           |
|  +------------------------------+     +------------------------------+     +------------------------------+      |
|  | Node 1: devops-multinode     |     | Node 2: devops-multinode-m02 |     | Node 3: devops-multinode-m03 |      |
|  | (Control Plane & Worker)     |     | (Worker Node)                |     | (Worker Node)                |      |
|  +------------------------------+     +------------------------------+     +------------------------------+      |
|  | - [Pod] shopping-cart-1      |     | - [Pod] shopping-cart-2      |     | - [Pod] shopping-cart-3      |      |
|  |                              |     | - [Pod] product-catalog-1    |     | - [Pod] product-catalog-2    |      |
|  +------------------------------+     +------------------------------+     +------------------------------+      |
|                 ^                                      ^                                      ^                  |
|                 |                                      |                                      |                  |
+-----------------|--------------------------------------|--------------------------------------|------------------+
                  |                                      |                                      |
                  +--------------------------------------+--------------------------------------+
                                                         |
                                 +------------------------------------------------+
                                 |          Kubernetes NodePort Services          |
                                 | - product-catalog-service (NodePort :80)       |
                                 | - shopping-cart-service (NodePort :80)         |
                                 +------------------------------------------------+
```

---

## Directory Structure

```
Exercise 10/
├── Dockerfile.product              # Container definition for Product Catalog
├── Dockerfile.shopping             # Container definition for Shopping Cart
├── cleanup.sh                      # Automated teardown script for cluster resources
├── deploy.sh                       # One-touch orchestration script (build, load, deploy)
├── k8s-manifests/                  # Declarative Kubernetes YAML manifests
│   ├── product_catalog_deployment.yaml   # 2-replica deployment with podAntiAffinity
│   ├── product_catalog_service.yaml      # NodePort service for product catalog
│   ├── shopping_cart_deployment.yaml     # 3-replica deployment with podAntiAffinity
│   └── shopping_cart_service.yaml        # NodePort service for shopping cart
├── product_catalog.py              # Flask microservice for product catalog
├── shopping_cart.py                # Flask microservice for shopping cart
├── test_apps_local.py              # Local unit verification suite
├── test-services.sh                # End-to-end integration test querying endpoints
└── README.md                       # Comprehensive guide and technical runbook
```

---

## Step-by-Step Implementation

### Step 1: Provision 3-Node Minikube Cluster
Start a 3-node cluster with profile `devops-multinode` using Docker driver:

```bash
minikube start --nodes 3 -p devops-multinode --driver=docker
```

Verify that all three nodes are in `Ready` status:
```bash
kubectl get nodes -o wide
```

Expected output:
```text
NAME                   STATUS   ROLES           AGE     VERSION   INTERNAL-IP    OS-IMAGE             KERNEL-VERSION   CONTAINER-RUNTIME
devops-multinode       Ready    control-plane   2m15s   v1.37.0   192.168.58.2   Ubuntu 24.04.1 LTS   ...              containerd://2.3.4
devops-multinode-m02   Ready    <none>          1m30s   v1.37.0   192.168.58.3   Ubuntu 24.04.1 LTS   ...              containerd://2.3.4
devops-multinode-m03   Ready    <none>          45s     v1.37.0   192.168.58.4   Ubuntu 24.04.1 LTS   ...              containerd://2.3.4
```

---

### Step 2: Implement the Microservices

#### 1. Product Catalog Service (`product_catalog.py`)
```python
from flask import Flask, jsonify

app = Flask(__name__)

products = [
    {"id": 1, "name": "Laptop", "price": 1200},
    {"id": 2, "name": "Phone", "price": 800},
    {"id": 3, "name": "Headphones", "price": 150},
]

@app.route("/products", methods=["GET"])
def get_products():
    return jsonify(products)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
```

#### 2. Shopping Cart Service (`shopping_cart.py`)
```python
from flask import Flask, jsonify, request

app = Flask(__name__)

cart = []

@app.route("/cart", methods=["GET"])
def get_cart():
    return jsonify(cart)

@app.route("/cart", methods=["POST"])
def add_to_cart():
    item = request.get_json(force=True, silent=False)
    if not item:
        return jsonify({"error": "Invalid request body"}), 400
    cart.append(item)
    return jsonify(cart), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
```

---

### Step 3: Containerize Applications

Build the Docker images locally:
```bash
docker build -t product-catalog:latest -f Dockerfile.product .
docker build -t shopping-cart:latest -f Dockerfile.shopping .
```

Verify images are present:
```bash
docker images | grep -E "product-catalog|shopping-cart"
```

---

### Step 4: Load Images Across the Multi-Node Cluster
In a single-node cluster with `eval $(minikube docker-env)`, images built inside the daemon are directly accessible. However, in a **multi-node cluster**, images must be distributed to all worker nodes.

Use Minikube's `image load` to propagate the images to all 3 nodes:
```bash
minikube -p devops-multinode image load product-catalog:latest
minikube -p devops-multinode image load shopping-cart:latest
```

---

### Step 5: Author Declarative Deployments with Pod Anti-Affinity

#### Product Catalog Deployment (`k8s-manifests/product_catalog_deployment.yaml`)
Enforces that 2 replicas never co-locate on the same node:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-catalog
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: product-catalog
  template:
    metadata:
      labels:
        app: product-catalog
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: product-catalog
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: product-catalog-container
        image: product-catalog:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
```

#### Shopping Cart Deployment (`k8s-manifests/shopping_cart_deployment.yaml`)
Enforces that 3 replicas spread across all 3 nodes:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shopping-cart
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: shopping-cart
  template:
    metadata:
      labels:
        app: shopping-cart
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: shopping-cart
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: shopping-cart-container
        image: shopping-cart:latest
        imagePullPolicy: Never
        ports:
        - containerPort: 80
```

Apply the manifests:
```bash
kubectl apply -f k8s-manifests/product_catalog_deployment.yaml
kubectl apply -f k8s-manifests/shopping_cart_deployment.yaml
kubectl apply -f k8s-manifests/product_catalog_service.yaml
kubectl apply -f k8s-manifests/shopping_cart_service.yaml
```

---

### Step 6: Verify Multi-Node Distribution

Check node assignments:
```bash
kubectl get pods -o wide --selector="app in (product-catalog, shopping-cart)"
```

#### Verified Distribution Matrix:
| Pod Name | App Label | Scheduled Node | Multi-Node Spread Verified |
|---|---|---|---|
| `shopping-cart-xxxx-1` | `shopping-cart` | `devops-multinode` | ✅ Node 1 |
| `shopping-cart-xxxx-2` | `shopping-cart` | `devops-multinode-m02` | ✅ Node 2 |
| `shopping-cart-xxxx-3` | `shopping-cart` | `devops-multinode-m03` | ✅ Node 3 |
| `product-catalog-xxxx-1`| `product-catalog`| `devops-multinode-m02` | ✅ Node 2 |
| `product-catalog-xxxx-2`| `product-catalog`| `devops-multinode-m03` | ✅ Node 3 |

Notice how no two pods of the same application share a node!

---

### Step 7: Live Endpoint Testing via `curl`

Execute automated tests:
```bash
./"Exercise 10"/test-services.sh
```

#### 1. Retrieve Product Catalog (`GET /products`):
```bash
curl http://127.0.0.1:38081/products
```
Response:
```json
[
  {"id": 1, "name": "Laptop", "price": 1200},
  {"id": 2, "name": "Phone", "price": 800},
  {"id": 3, "name": "Headphones", "price": 150}
]
```

#### 2. Query Shopping Cart (`GET /cart`):
```bash
curl http://127.0.0.1:38082/cart
```
Response:
```json
[]
```

#### 3. Add Item to Cart (`POST /cart`):
```bash
curl -X POST http://127.0.0.1:38082/cart \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "name": "Laptop", "quantity": 1}'
```
Response:
```json
[
  {"id": 1, "name": "Laptop", "quantity": 1}
]
```

---

## 💡 Key Takeaways & Production Patterns

1. **Topology Keys for Blast Radius Reduction**:
   Using `topologyKey: "kubernetes.io/hostname"` protects against node loss. In cloud providers (EKS, GKE, AKS), you can use `topology.kubernetes.io/zone` to spread replicas across separate **Availability Zones (AZs)** to survive whole data center outages.
2. **Hard (`required`) vs Soft (`preferred`) Anti-Affinity**:
   - `requiredDuringSchedulingIgnoredDuringExecution`: Strict anti-affinity. If there are fewer nodes than replicas, surplus pods remain `Pending`.
   - `preferredDuringSchedulingIgnoredDuringExecution`: Best-effort anti-affinity. Pods prefer different nodes, but can co-locate if node capacity is constrained.
3. **Multi-Node Image Distribution**:
   Unlike single-node Minikube, container images must be loaded into each node or pushed to a container registry accessible by all Kubelets.
