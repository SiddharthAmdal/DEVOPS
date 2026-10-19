# Exercise 4: Docker Networking with Multiple Containers

## Objective
Understand Docker networking fundamentals, container-to-container communication, and DNS service discovery by configuring a multi-container architecture connected via a custom user-defined bridge network.

---

## Architecture Scenario: 3-Tier Multi-Container Stack

```
                                  +---------------------------------------+
                                  | Host Machine (macOS / Linux / Windows)|
                                  | Access: http://localhost:5001/about  |
                                  +---------------------------------------+
                                                     |
                                            Port Mapping: -p 5001:5001
                                                     |
                                                     v
=========================================[ my-bridge-net (172.18.0.0/16) ]=========================================
      |                                              |                                             |
      v                                              v                                             v
+-----------------------------+        +-----------------------------+               +-----------------------------+
| Container: flask            |        | Container: mysql            |               | Container: redis            |
| Image: flask-api            | =====> | Image: mysql:latest         |        =====> | Image: redis:latest         |
| IP: 172.18.0.4 (example)    | DNS    | IP: 172.18.0.2 (example)    |        DNS    | IP: 172.18.0.3 (example)    |
| Port: 5001 (Exposed: 5001)  | Ping   | Port: 3306 (Internal only)  |        Ping   | Port: 6379 (Internal only)  |
+-----------------------------+        +-----------------------------+               +-----------------------------+
====================================================================================================================
```

* **Container 1 (`flask`)**: Lightweight Flask REST API web server providing an `/about` route.
* **Container 2 (`mysql`)**: Relational database storage engine running MySQL.
* **Container 3 (`redis`)**: In-memory caching and session store running Redis.

---

## Exercise Implementation Roadmap

- [x] **Phase 1: Custom Bridge Network Definition & Flask Application Containerization**
  - Explore default bridge vs. user-defined bridge network mechanics (embedded DNS resolution).
  - Create and inspect custom bridge network `my-bridge-net` (`docker network create`, `docker network inspect`).
  - Implement Flask application ([`app.py`](./app.py)), pinned dependencies ([`requirements.txt`](./requirements.txt)), and diagnostic-ready container specification ([`Dockerfile`](./Dockerfile)).
- [x] **Phase 2: Multi-Container Deployment & Host Port Exposure**
  - Build `flask-api` image locally.
  - Launch `mysql`, `redis`, and `flask` containers attached to `my-bridge-net`.
  - Configure host port mapping (`-p 5001:5001`) and verify web API availability via `curl`.
  - Provide declarative `docker-compose.yaml` specification.
- [ ] **Phase 3: Inter-Container DNS Connectivity Testing, Teardown & Conceptual Q&A**
  - Execute live container-to-container connectivity tests (`ping mysql`, `ping redis` from inside `flask`).
  - Document network teardown commands and complete theoretical Q&A.
  - Provide automated execution scripts ([`run-network-lab.sh`](./run-network-lab.sh), [`cleanup.sh`](./cleanup.sh)).

---

## Phase 1: Custom Bridge Network Definition & Flask Application Containerization

### 1. Default Bridge vs. User-Defined Custom Bridge Networks

| Feature | Default `bridge` Network | User-Defined Custom Bridge (`my-bridge-net`) |
| :--- | :--- | :--- |
| **Container DNS Resolution** | ❌ None (containers can only ping each other by raw IP address unless legacy `--link` is used) | ✅ **Automatic Built-in DNS Resolution** (containers can communicate using container names directly, e.g. `mysql`, `redis`) |
| **Network Isolation** | ❌ All containers connect to default bridge by default, increasing security risk | ✅ **Hardened Isolation** (only containers explicitly attached via `--net` can reach each other) |
| **Configurability** | ❌ Fixed subnet and gateway | ✅ Custom subnet, gateway, IPAM, and MTU options |
| **Hot-Plugging** | ❌ Containers cannot be disconnected without stopping | ✅ Can attach/detach running containers on the fly (`docker network connect/disconnect`) |

---

### 2. Task 1: Create a Bridge Network
Create an isolated bridge network named `my-bridge-net`:

```bash
docker network create --driver bridge my-bridge-net
```
*Expected Output*: Returns the 64-character Network ID hash (e.g. `87c23b491f5994c74e497f4f4f4f4f4f4f4f4...`).

---

### 3. Task 2: Verify the Network
List all Docker networks to verify `my-bridge-net` is present:

```bash
docker network ls
```
*Expected Output*:
```text
NETWORK ID     NAME            DRIVER    SCOPE
87c23b491f59   my-bridge-net   bridge    local
```

---

### 4. Task 3: Inspect the Network
Inspect the network parameters, allocated subnet, and gateway:

```bash
docker network inspect my-bridge-net
```
*Expected Output*:
```json
[
  {
    "Name": "my-bridge-net",
    "Scope": "local",
    "Driver": "bridge",
    "EnableIPv6": false,
    "IPAM": {
      "Driver": "default",
      "Config": [
        {
          "Subnet": "172.18.0.0/16",
          "Gateway": "172.18.0.1"
        }
      ]
    },
    "Containers": {}
  }
]
```

---

### 5. Flask Web Application (`app.py`)
A simple REST service exposing an `/about` route returning metadata in JSON format:

```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/about', methods=['GET'])
def about():
    return jsonify({
        "name": "Simple REST API",
        "version": "1.0",
        "description": "This is a simple REST API built with Flask."
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)
```

---

### 6. Containerization Specification (`Dockerfile`)
The `Dockerfile` is built on `python:3.9-slim` and includes `iputils-ping` and `curl` for container network testing:

```dockerfile
FROM python:3.9-slim
WORKDIR /app
RUN apt-get update && \
    apt-get install -y --no-install-recommends iputils-ping curl && \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
COPY app.py .
RUN pip install --no-cache-dir -r requirements.txt
EXPOSE 5001
CMD ["python", "app.py"]
```

---

## Phase 2: Multi-Container Deployment & Host Port Exposure

### 1. Step 1: Build the Flask API Image
Build the container image tagged as `flask-api`:

```bash
docker build -t flask-api "Exercise 4"
```

---

### 2. Step 2: Launch Containers on `my-bridge-net`
Run each container in detached mode (`-d`) attached to the `my-bridge-net` network:

#### 1. MySQL Container
```bash
docker run -d --name mysql --net=my-bridge-net -e MYSQL_ROOT_PASSWORD=root mysql:latest
```

#### 2. Redis Container
```bash
docker run -d --name redis --net=my-bridge-net redis:latest
```

#### 3. Flask API Container (with Host Port Mapping)
```bash
docker run -d --name flask --net=my-bridge-net -p 5001:5001 flask-api
```

---

### 3. Command Flags Deep Dive

| Flag | Purpose | Explanation |
| :--- | :--- | :--- |
| **`-d`** | Detached Mode | Runs the container in the background, freeing your terminal. |
| **`--name <name>`** | Container Name | Assigns a persistent DNS hostname reachable by all containers on the same user-defined bridge. |
| **`--net=my-bridge-net`** | Network Attachment | Attaches the container to our custom bridge network instead of the default bridge. |
| **`-p 5001:5001`** | Port Mapping | Binds `HostPort:ContainerPort`. Forwards incoming traffic on the host's `5001` port to the container's internal `5001` port. |
| **`-e MYSQL_ROOT_PASSWORD=root`** | Environment Variable | Supplies the mandatory root password required by the official MySQL image. |

---

### 4. Step 3: Verify Running Containers & Network Membership

List all active containers:
```bash
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
```
Expected output:
```text
NAMES   IMAGE          STATUS         PORTS
flask   flask-api      Up 10 seconds  0.0.0.0:5001->5001/tcp
redis   redis:latest   Up 20 seconds  6379/tcp
mysql   mysql:latest   Up 30 seconds  3306/tcp, 33060/tcp
```

Inspect `my-bridge-net` to verify IP allocations:
```bash
docker network inspect my-bridge-net
```
Under the `"Containers"` block, all 3 containers are assigned sequential private IP addresses on the `172.18.0.0/16` subnet (e.g. `172.18.0.2`, `172.18.0.3`, `172.18.0.4`).

---

### 5. Step 4: Verify Host Access to the Flask API
Since `flask` was exposed using `-p 5001:5001`, you can access the `/about` endpoint directly from your host:

```bash
curl -i http://localhost:5001/about
```
Expected HTTP response:
```http
HTTP/1.0 200 OK
Content-Type: application/json
Content-Length: 104
Server: Werkzeug/2.2.2 Python/3.9...

{
  "description": "This is a simple REST API built with Flask.",
  "name": "Simple REST API",
  "version": "1.0"
}
```

---

### 6. Declarative Orchestration Alternative (`docker-compose.yaml`)
To launch this entire 3-tier architecture with a single command, you can use the included [`docker-compose.yaml`](./docker-compose.yaml):

```bash
docker compose -f "Exercise 4/docker-compose.yaml" up -d
```

