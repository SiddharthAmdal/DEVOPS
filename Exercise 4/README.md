# Exercise 4: Docker Networking with Multiple Containers

> 🔗 **Original Lab Exercise**: [4-Docker-Networking.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/4-Docker-Networking.md)

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
- [x] **Phase 3: Inter-Container DNS Connectivity Testing, Teardown & Conceptual Q&A**
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

---

## Phase 3: Inter-Container DNS Connectivity Testing, Teardown & Conceptual Q&A

### 1. Task 5: Testing Container-to-Container DNS Connectivity

On a user-defined bridge network (`my-bridge-net`), Docker provides an automatic embedded DNS server at `127.0.0.11`. Containers can communicate using container names as hostnames without needing to know internal IP addresses.

#### Test 1: Ping MySQL from the Flask Container
Open an interactive terminal or execute the ping command directly inside the `flask` container:

```bash
docker exec -it flask ping -c 3 mysql
```
*Expected Output*:
```text
PING mysql (172.18.0.2) 56(84) bytes of data.
64 bytes from mysql.my-bridge-net (172.18.0.2): icmp_seq=1 ttl=64 time=0.078 ms
64 bytes from mysql.my-bridge-net (172.18.0.2): icmp_seq=2 ttl=64 time=0.065 ms
64 bytes from mysql.my-bridge-net (172.18.0.2): icmp_seq=3 ttl=64 time=0.071 ms

--- mysql ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2045ms
rtt min/avg/max/mdev = 0.065/0.071/0.078/0.005 ms
```
*Result*: The container name `mysql` was automatically resolved to its internal bridge IP (`172.18.0.2`).

#### Test 2: Ping Redis from the Flask Container
```bash
docker exec -it flask ping -c 3 redis
```
*Expected Output*:
```text
PING redis (172.18.0.3) 56(84) bytes of data.
64 bytes from redis.my-bridge-net (172.18.0.3): icmp_seq=1 ttl=64 time=0.081 ms
64 bytes from redis.my-bridge-net (172.18.0.3): icmp_seq=2 ttl=64 time=0.069 ms
64 bytes from redis.my-bridge-net (172.18.0.3): icmp_seq=3 ttl=64 time=0.074 ms

--- redis ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2048ms
rtt min/avg/max/mdev = 0.069/0.074/0.081/0.005 ms
```
*Result*: The container name `redis` was automatically resolved to its internal bridge IP (`172.18.0.3`).

---

### 2. Task 6: Teardown & Environment Cleanup

#### Step 1: Stop and Remove Containers
```bash
docker stop mysql redis flask && docker rm mysql redis flask
```
*Expected Output*:
```text
mysql
redis
flask
```

#### Step 2: Remove the Custom Bridge Network
```bash
docker network rm my-bridge-net
```
*Expected Output*:
```text
my-bridge-net
```

---

### 3. Comprehensive Conceptual Q&A

#### Q1: What is the purpose of the `--net` flag in `docker run`?
> **Answer**: The `--net` (or `--network`) flag specifies the network to which the container connects upon creation. Attaching multiple containers to the same user-defined bridge network places them in an isolated virtual LAN and activates Docker's embedded DNS service discovery, enabling them to communicate seamlessly using container names.

#### Q2: How do containers communicate with each other on the same network?
> **Answer**: Containers communicate over private IP addresses or by using **container names** (or network aliases) as hostnames. On user-defined bridge networks, Docker's internal DNS daemon (listening at `127.0.0.11`) intercepts name queries and resolves container names (e.g. `mysql`, `redis`) directly to their container IP addresses.

#### Q3: What is the difference between a bridge network and a host network?
> **Answer**:
> * **Bridge Network (Default / Isolated)**:
>   - Creates an isolated virtual software bridge (e.g. `172.18.0.0/16`).
>   - Containers receive private, dedicated IP addresses and isolated port namespaces.
>   - Access from the host machine requires explicit port publishing (`-p <host_port>:<container_port>`).
>   - *Analogy*: Containers are in private rooms, communicating through defined doors.
> * **Host Network (`--net=host`)**:
>   - Disables container network namespace isolation.
>   - The container shares the host machine’s networking stack, IP address, and interfaces directly.
>   - A service running on port 5001 inside the container is immediately bound to port 5001 on the host without needing `-p`.
>   - *Analogy*: Containers are in the same room as the host, talking directly with no barriers.

#### Q4: How can you expose a container's port to the host machine?
> **Answer**: By using the `-p` (or `--publish`) flag during `docker run`, with the syntax `-p <HostPort>:<ContainerPort>` (for example, `-p 5001:5001`). This adds NAT/iptables rules on the host to forward incoming connections from the host port directly to the listening port inside the container.

---

### 4. Operational Automation Scripts

#### Run End-to-End Networking Lab
Builds image, provisions network, runs all 3 containers, tests DNS ping to mysql/redis, and tests the Flask API:
```bash
./"Exercise 4/run-network-lab.sh"
```

#### Teardown Lab Environment
Stops and deletes containers and deletes `my-bridge-net`:
```bash
./"Exercise 4/cleanup.sh"
```


