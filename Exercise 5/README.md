# Exercise 5: Docker Security with AppArmor and Python

## Objective
Understand container hardening using **AppArmor** (Application Armor)—a Linux Security Module (LSM) that provides **Mandatory Access Control (MAC)**. In this exercise, you will learn how to:
1. Define custom AppArmor security profiles restricting file access, binary execution, and Linux capabilities.
2. Apply AppArmor profiles programmatically to Docker containers using the **Docker SDK for Python**.
3. Verify security enforcement by testing restricted actions (e.g., reading `/etc/passwd` or launching `/bin/bash`) and observing non-zero exit codes.

---

## Security Context & Architectural Principles

### 1. Discretionary Access Control (DAC) vs. Mandatory Access Control (MAC)
* **DAC (Standard Linux permissions)**: Users own objects and determine who can read/write/execute them based on user/group IDs. If a container process runs as `root` (UID 0), DAC grants it full access to all container files and resources.
* **MAC (AppArmor / SELinux)**: The operating system kernel enforces access rules defined in security profiles, regardless of user privileges. Even if a process runs as `root` inside the container, AppArmor intercepts kernel syscalls and blocks forbidden actions.

### 2. Threat Mitigation in Multi-Tenant Environments
In a production web application, if an attacker executes arbitrary code via a web vulnerability (e.g., Remote Code Execution / command injection), an AppArmor profile provides **defense-in-depth**:
* 🛑 **Blocks Credential Harvesting**: Prevents reading sensitive system files (`/etc/passwd`, `/etc/shadow`, `/etc/hosts`).
* 🛑 **Prevents Shell Escapes**: Denies executing interactive binaries (`/bin/bash`, `/bin/sh`, `/usr/bin/python`).
* 🛑 **Drops Kernel Capabilities**: Forbids `sys_admin` capabilities, preventing container escapes.

---

## Exercise Implementation Roadmap

- [x] **Phase 1: Flask Application, Containerization & AppArmor Profile Definition**
  - Implement basic Python Flask web service ([`app.py`](./app.py)).
  - Specify dependencies in [`requirements.txt`](./requirements.txt).
  - Create container specification ([`Dockerfile`](./Dockerfile) & [`.dockerignore`](./.dockerignore)).
  - Define custom AppArmor profile ([`my-apparmor-profile`](./my-apparmor-profile)) restricting filesystem, binary execution, and capabilities.
- [x] **Phase 2: Docker SDK Integration & Profile Application**
  - Write Python automation script ([`apply_apparmor.py`](./apply_apparmor.py)) using Docker SDK.
  - Configure container launch with `security_opt=["apparmor=my-apparmor-profile"]`.
  - Programmatically inspect container `HostConfig.SecurityOpt` to verify profile enforcement.
- [ ] **Phase 3: Security Restriction Testing, Verification Scripts & Analysis**
  - Implement security verification script ([`test_restricted_actions.py`](./test_restricted_actions.py)).
  - Test blocked file access (`cat /etc/passwd` $\rightarrow$ Exit Code 1).
  - Test blocked binary execution (`/bin/bash` $\rightarrow$ Exit Code 126).
  - Provide operational automation scripts ([`setup-and-run.sh`](./setup-and-run.sh), [`cleanup.sh`](./cleanup.sh)).

---

## Phase 1: Flask Application, Containerization & AppArmor Profile Definition

### 1. Flask Web Application (`app.py`)
A basic Flask web application that serves as the target workload:

```python
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Hello, this is a secure Flask application running inside a Docker container!"

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
```

---

### 2. Containerization (`Dockerfile`)
Uses `python:3.8-slim` to minimize the initial attack surface:

```dockerfile
FROM python:3.8-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . /app
EXPOSE 5000
CMD ["python", "app.py"]
```

Build the container image:
```bash
docker build -t flask-apparmor "Exercise 5"
```

---

### 3. AppArmor Profile Breakdown (`my-apparmor-profile`)

```apparmor
#include <tunables/global>

/usr/bin/python3 {
    # Deny access to sensitive system files
    deny /etc/** r,
    deny /var/** rw,

    # Allow Flask app to bind to port 5000
    network inet stream,

    # Permissions to the application directory
    /app/** rwk,

    # Deny execution of any binaries in /bin or /usr/bin
    deny /bin/** rmix,
    deny /usr/bin/** rmix,

    # Capability restrictions
    capability net_bind_service,
    deny capability sys_admin,
}
```

#### Rule-by-Rule Explanation:
* **`#include <tunables/global>`**: Imports common AppArmor variables and macros.
* **`/usr/bin/python3`**: Target binary attachment path defining the enforcement scope.
* **`deny /etc/** r`**: Explicitly denies read access (`r`) to all files and subdirectories under `/etc/`.
* **`deny /var/** rw`**: Denies read and write access under `/var/`.
* **`network inet stream`**: Permits TCP streaming sockets so Flask can accept incoming HTTP connections.
* **`/app/** rwk`**: Grants read (`r`), write (`w`), and file locking (`k`) permissions inside the application root directory.
* **`deny /bin/** rmix` & `deny /usr/bin/** rmix`**: Prohibits reading, memory-mapping, or executing (`mix`) any binary in standard system binary directories.
* **`capability net_bind_service`**: Allows binding to privileged network ports.
* **`deny capability sys_admin`**: Drops the dangerous `CAP_SYS_ADMIN` capability (often exploited in container escapes).

---

## Phase 2: Docker SDK Integration & Profile Application

### 1. Loading the Profile into the Linux Kernel
AppArmor operates at the kernel level. Before Docker can attach a profile to a container, the profile definition must be compiled and loaded into the Linux kernel using `apparmor_parser`.

#### On Ubuntu / Debian Hosts:
```bash
# 1. Install AppArmor parser utilities if missing
sudo apt-get update && sudo apt-get install -y apparmor-utils

# 2. Copy the profile to the standard AppArmor directory
sudo cp "Exercise 5/my-apparmor-profile" /etc/apparmor.d/my-apparmor-profile

# 3. Compile and reload the profile into the Linux kernel
sudo apparmor_parser -r /etc/apparmor.d/my-apparmor-profile

# 4. Verify the profile is loaded in enforce mode
sudo aa-status | grep my-apparmor-profile
```

---

### 2. Manual CLI Application
Once loaded into the kernel, Docker can apply the profile using the `--security-opt` flag:

```bash
docker run -d --name flask-secure \
  --security-opt="apparmor=my-apparmor-profile" \
  -p 5000:5000 flask-apparmor
```

Verify that Docker has recorded the security option:
```bash
docker inspect flask-secure --format '{{.HostConfig.SecurityOpt}}'
```
*Expected Output*: `[apparmor=my-apparmor-profile]`

---

### 3. Programmatic Automation via Docker SDK for Python (`apply_apparmor.py`)
In automated CI/CD and deployment pipelines, profiles are applied programmatically using Python's official `docker` SDK:

```python
import docker
import os

client = docker.from_env()
script_dir = os.path.dirname(os.path.abspath(__file__))

print("Building image from Dockerfile...")
client.images.build(path=script_dir, tag="flask-apparmor", rm=True)
print("Successfully built flask-apparmor\n")

print("Running container with AppArmor profile...")
container = client.containers.run(
    "flask-apparmor",
    ports={'5000/tcp': 5000},
    security_opt=["apparmor=my-apparmor-profile"],
    detach=True
)

print(f"Container started: {container.short_id}\n")

print("Inspecting container to verify AppArmor profile...")
container_info = client.api.inspect_container(container.id)
apparmor_profile = container_info['HostConfig']['SecurityOpt']

print(f"AppArmor profile applied: {apparmor_profile}\n")

print("Stopping the container...")
container.stop()
container.remove()
print("Container stopped and removed.")
```

#### Execution & Expected Output:
```bash
python apply_apparmor.py
```
```text
Building image from Dockerfile...
[INFO] Sending build context to Docker daemon  3.072kB
Successfully built flask-apparmor

Running container with AppArmor profile...
Container started: f8c2a7f9b9b8

Inspecting container to verify AppArmor profile...
AppArmor profile applied: ['apparmor=my-apparmor-profile']

Stopping the container...
Container stopped and removed.
```

