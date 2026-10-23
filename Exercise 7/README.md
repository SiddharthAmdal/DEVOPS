# Exercise 7: Introduction to Continuous Integration (CI) and Jenkins Installation

> 🔗 **Original Lab Exercise**: [7-Jenkins-CI-Automation.md](https://github.com/SunagP/DevOps-Lab/blob/main/Exercises/7-Jenkins-CI-Automation.md)

## Objective
Continuous Integration (CI) is a core software development practice where engineers frequently integrate code changes into a shared version-controlled repository. Each integration is verified through automated builds and testing to detect regressions and integration conflicts early.

In this exercise, you will:
1. Master core **Continuous Integration (CI)** principles, workflows, and benefits.
2. Evaluate and compare the **top 10 industry CI/CD tools** (GitLab CI, GitHub Actions, Jenkins, CircleCI, Travis CI, Bamboo, TeamCity, Azure DevOps, Spinnaker, Drone).
3. Understand the architecture of **Jenkins**, the leading open-source automation server.
4. Containerize and deploy Jenkins using **Docker** with volume persistence and port mappings (`8080` for Web UI, `50000` for build agents).
5. Extract the initial administrative security credential from `/var/jenkins_home/secrets/initialAdminPassword` and unlock the Jenkins management portal.

---

## Architectural Principles of Continuous Integration (CI)

```
+----------------------------------------------------------------------------------------------------+
|                                    Continuous Integration Lifecycle                                |
+----------------------------------------------------------------------------------------------------+
     |
     v
1. Developer Workspace
   * Feature branch development
   * Local unit testing & linting
     |
     | Git Push
     v
2. Shared Source Repository (GitHub / GitLab)
   * Pull request / Merge request created
   * Webhook event dispatched to CI Server
     |
     | Webhook Event
     v
3. CI Server (Jenkins Controller)
   * Pulls latest commit SHA
   * Resolves dependencies
   * Dispatches build jobs to build agents
     |
     +-----------------------------------+
     |                                   |
     v                                   v
4. Automated Build & Compilation     5. Automated Quality & Security Testing
   * Binary compilation                 * Unit testing
   * Dependency resolution              * Integration testing
   * Docker image creation              * Code coverage & security scans (SonarQube)
     |                                   |
     +-----------------+-----------------+
                       |
                       v
                 6. Feedback Loop
                    * Status checks reported back to Pull Request (Pass/Fail)
                    * Build artifacts published to repository
                    * Developer notified within minutes
```

---

## The 4 Pillars of Modern CI

1. **Frequent Code Commits**:
   Developers push small, incremental changes to the shared repository multiple times daily rather than maintaining long-lived, divergent branches.
2. **Automated Builds**:
   Every code change automatically triggers a clean build from scratch, resolving all dependencies and verifying compilation integrity.
3. **Automated Testing**:
   Comprehensive test suites (unit, component, integration, and security checks) run in isolated test runners to ensure zero regression.
4. **Immediate Feedback Loop**:
   Build results, execution logs, and failure stack traces are communicated back to engineers within minutes via GitHub status checks, Slack, or email.

---

## Top 10 CI/CD Tools: Industry Comparison Matrix

| Tool | Hosting Model | Configuration Syntax | Key Strengths | Ideal Enterprise Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **Jenkins** | Self-hosted / Kubernetes | Declarative / Scripted Groovy (`Jenkinsfile`) | 1,800+ plugins, completely open-source, massive ecosystem, full customization | Complex on-premise, hybrid, and enterprise environments requiring custom pipeline logic. |
| **GitHub Actions** | SaaS / Self-hosted Runners | YAML (`.github/workflows/*.yml`) | Native GitHub integration, rich Marketplace actions, matrix builds | Teams hosting code on GitHub wanting zero-friction setup. |
| **GitLab CI/CD** | SaaS / Self-hosted | YAML (`.gitlab-ci.yml`) | Built-in Auto DevOps, single platform for issues, repo, CI/CD, and registry | Organizations utilizing GitLab for end-to-end DevOps lifecycle management. |
| **CircleCI** | Cloud SaaS / Server | YAML (`.circleci/config.yml`) | Excellent container support, parallelism, caching, fast execution | Fast-moving startups and teams heavily reliant on Dockerized pipelines. |
| **Travis CI** | Cloud SaaS | YAML (`.travis.yml`) | Pioneer in open-source CI, multi-language support out-of-the-box | Open-source public projects and small development teams. |
| **Atlassian Bamboo** | Self-hosted | YAML / Java Specs / UI | Deep integration with Jira, Bitbucket, Confluence, and deployment projects | Enterprise teams fully invested in the Atlassian toolchain. |
| **JetBrains TeamCity** | Self-hosted / Cloud | Kotlin DSL / Web UI / XML | Intelligent build history, deep IDE integrations, robust multi-project builds | Teams using JetBrains tools requiring type-safe Kotlin DSL configurations. |
| **Azure Pipelines** | Cloud SaaS / Self-hosted | YAML (`azure-pipelines.yml`) | Native integration with Azure cloud, Visual Studio, and multi-platform agents | Enterprise Microsoft environments and cross-cloud deployments. |
| **Spinnaker** | Cloud-native (Kubernetes) | JSON / Web UI | Multi-cloud deployment orchestration, automated Canary analysis, Blue/Green | CD-focused cloud-native platforms needing advanced deployment strategies. |
| **Drone CI** | Lightweight Self-hosted | YAML (`.drone.yml`) | Entirely container-native; every step executes inside isolated Docker containers | Modern container-first workflows with minimal infrastructure overhead. |

---

## Jenkins Architecture & Key Concepts

```
                             +-------------------------------+
                             |       Jenkins Controller      |
                             |   (Master Node - Port 8080)   |
                             |  * Web Management Dashboard   |
                             |  * Job Scheduling & Config    |
                             |  * Plugin & Security Manager  |
                             +-------------------------------+
                                            |
                                            | JNLP Agent Communication (Port 50000)
                    +-----------------------+-----------------------+
                    |                                               |
                    v                                               v
     +-----------------------------+                 +-----------------------------+
     |     Build Agent (Node 1)    |                 |     Build Agent (Node 2)    |
     |   * Docker Engine           |                 |   * Kubernetes Pod Agent    |
     |   * Workspace Execution     |                 |   * Workspace Execution     |
     +-----------------------------+                 +-----------------------------+
```

### Core Terminology:
* **Controller (Master)**: Coordinates build scheduling, hosts the Web UI (`http://localhost:8080`), manages plugins, and monitors nodes.
* **Agent (Node)**: Worker machines or containers responsible for executing the commands defined in a pipeline job. Communicates with the controller over JNLP on port `50000`.
* **Job / Project**: A configured user task (e.g., Freestyle project, Multibranch pipeline, Maven build).
* **Pipeline**: A user-defined continuous delivery model written in code (`Jenkinsfile`) using Groovy syntax.
* **Plugins**: Modular extensions that integrate Jenkins with version control (Git, GitHub), build tools (Maven, Gradle), and runtimes (Docker, Kubernetes).
* **Workspace**: A dedicated directory on the agent filesystem where source files are cloned and build artifacts are compiled.

---

## Exercise Implementation Roadmap

- [x] **Phase 1: CI/CD Fundamentals & Enterprise Tooling Matrix**
  - Establish `Exercise 7/` workspace directory.
  - Formulate detailed conceptual framework of Continuous Integration.
  - Compile comprehensive comparative evaluation of top 10 industry CI/CD platforms.
  - Document Jenkins architecture (Controller vs Agent topologies, ports `8080` and `50000`).

- [x] **Phase 2: Jenkins Containerization, Volume Persistence & Port Orchestration**
  - Create automated deployment runner ([`install-jenkins.sh`](./install-jenkins.sh)) targeting `jenkins/jenkins:lts`.
  - Configure port forwarding for Web Management (`8080:8080`) and Agent JNLP communication (`50000:50000`).
  - Attach Docker named volume `jenkins_home` for persistent configurations and job history.
  - Implement security token extraction utility ([`get-admin-password.sh`](./get-admin-password.sh)).
  - Provide teardown and volume management script ([`cleanup.sh`](./cleanup.sh)).

- [x] **Phase 3: Initialization, Verification & Browser Workflow Validation**
  - Launch Jenkins locally and verify container runtime health.
  - Retrieve the active initial administrator password from `/var/jenkins_home/secrets/initialAdminPassword`.
  - Validate the "Unlock Jenkins" administrative authentication gate.
  - Verify suggested plugin installation and main dashboard accessibility (`Welcome to Jenkins!`).

---

## Phase 2: Jenkins Containerization, Volume Persistence & Port Orchestration

### 1. Automated Installation & Deployment (`install-jenkins.sh`)

The deployment script automates provisioning the Jenkins LTS container:

```bash
#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="jenkins"
IMAGE_NAME="jenkins/jenkins:lts"
VOLUME_NAME="jenkins_home"
HTTP_PORT="8080"
AGENT_PORT="50000"

# Remove any existing container to ensure clean initialization
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Run Jenkins with volume persistence and port mappings
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HTTP_PORT}:8080" \
  -p "${AGENT_PORT}:50000" \
  -v "${VOLUME_NAME}:/var/jenkins_home" \
  "${IMAGE_NAME}"
```

#### Run Command:
```bash
./"Exercise 7/install-jenkins.sh"
```

---

### 2. Port Topologies & Storage Architecture

#### Port Mappings:
* **`-p 8080:8080` (Web Interface)**:
  Directs host traffic on port `8080` to the embedded Jetty web server inside the container. This is the entry point for accessing the web UI at [http://localhost:8080](http://localhost:8080).
* **`-p 50000:50000` (JNLP Agent Port)**:
  Exposes the inbound communication port used by remote distributed build agents connecting back to the Jenkins controller via the Java Network Launch Protocol (JNLP).

#### Persistent Volume:
* **`-v jenkins_home:/var/jenkins_home`**:
  Preserves Jenkins master state across container restarts and updates. This volume holds:
  - System configuration (`config.xml`)
  - Installed plugins (`/var/jenkins_home/plugins/`)
  - Pipeline definitions and jobs (`/var/jenkins_home/jobs/`)
  - Workspace history and build artifacts
  - Administrator secrets (`/var/jenkins_home/secrets/`)

---

### 3. Extracting the Initial Administrator Password

Upon first boot, Jenkins locks the user interface to prevent unauthorized access. The setup key is written to a protected file on the container filesystem:

#### Direct Retrieval Command:
```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

#### Dedicated Extraction Utility (`get-admin-password.sh`):
```bash
./"Exercise 7/get-admin-password.sh"
```

#### Generated Password for This Instance:
```text
========================================================================
 Jenkins Initial Administrator Password:
 cb47b05bae8a47ee9ab386d48e7151fe
========================================================================
Access the portal at: http://localhost:8080
```

---

### 4. Teardown & Lifecycle Script (`cleanup.sh`)

To cleanly remove the Jenkins container while preserving data:
```bash
./"Exercise 7/cleanup.sh"
```

To purge all data and delete the persistent Docker volume (`jenkins_home`):
```bash
./"Exercise 7/cleanup.sh" --all
```

---

## Phase 3: Initialization, Verification & Browser Workflow Validation

### 1. Step-by-Step Jenkins Onboarding Workflow

#### Step 1: Accessing the Web Interface
Navigate to [http://localhost:8080](http://localhost:8080) in your web browser. Jenkins displays the **Unlock Jenkins** security gate:

```text
Unlock Jenkins
To ensure Jenkins is securely set up by the administrator, a password has been written to the log and this file on the server:
/var/jenkins_home/secrets/initialAdminPassword
```

#### Step 2: Unlocking the Controller
Paste the extracted token into the **Administrator password** field:
```text
cb47b05bae8a47ee9ab386d48e7151fe
```
Click **Continue**.

---

### 2. Plugin Architecture & Customization

Upon successful authentication, Jenkins prompts for plugin selection:

```
+-------------------------------------------------------------+
|                      Customize Jenkins                      |
+-------------------------------------------------------------+
|  [ Install suggested plugins ]  |  [ Select plugins to install ] |
|  Plugins that the Jenkins       |  Select plugins that best  |
|  community finds most useful.   |  suit your needs.          |
+-------------------------------------------------------------+
```

Selecting **Install suggested plugins** automatically downloads, resolves, and activates the foundational suite:

| Plugin Category | Plugins Installed | Purpose in CI/CD |
| :--- | :--- | :--- |
| **Organization** | `Folders`, `OWASP Markup Formatter` | Hierarchical job grouping and secure HTML formatting. |
| **Build & Execution** | `Build Timeout`, `Timestamper`, `Workspace Cleanup` | Safeguarding build runtimes, adding ISO timestamps, and clearing disk space post-build. |
| **Pipeline Core** | `Pipeline`, `Pipeline: GitHub Groovy Libraries`, `Pipeline Graph View` | Groovy-based pipeline execution engine and visual stage graph rendering. |
| **Source Control (SCM)**| `Git`, `GitHub Branch Source` | Git cloning, branch indexing, webhook triggers, and commit SHA tracking. |
| **Security & Auth** | `Credentials Binding`, `Matrix Authorization Strategy`, `PAM Authentication`, `LDAP` | Secure secret injection (API tokens, SSH keys) and granular role-based access control (RBAC). |
| **Notifications** | `Email Extension`, `Mailer` | Automated build pass/fail email dispatch to committers. |
| **Agents & Scaling** | `SSH Build Agents` | Provisioning and launching remote worker nodes over SSH. |

---

### 3. Verification & UI Dashboards

Once plugin installation completes, Jenkins leads through optional admin account creation and instance URL confirmation (`http://localhost:8080/`), opening directly into the **Welcome to Jenkins!** main dashboard.

#### Core Dashboard Sections:
* **Create a Job**: Initiates a new pipeline, freestyle job, or multibranch project.
* **Build Queue**: Displays scheduled jobs waiting for available executor slots.
* **Build Executor Status**: Shows real-time agent workloads across master and worker nodes.
* **Manage Jenkins**: Central hub for system configurations, plugin updates, security credentials, and node topology.

---

### 4. Verification Summary Matrix

| Verification Item | Target / Command | Status | Result / Notes |
| :--- | :--- | :---: | :--- |
| **Container Execution** | `docker ps -a \| grep jenkins` | **UP** | Running on ports `8080` (HTTP) and `50000` (JNLP). |
| **Volume Mount** | `docker inspect jenkins` | **MOUNTED** | Volume `jenkins_home` mounted to `/var/jenkins_home`. |
| **Credential Retrieval** | `cat /var/jenkins_home/secrets/initialAdminPassword` | **VERIFIED** | Secret `cb47b05bae8a47ee9ab386d48e7151fe` generated. |
| **HTTP Web Console** | `curl -I http://localhost:8080/login` | **HTTP 200** | Jetty embedded web server responding cleanly. |
| **Unlock Jenkins Gate** | [http://localhost:8080](http://localhost:8080) | **PASSED** | Admin secret submitted and accepted. |
| **Plugin Setup** | [http://localhost:8080](http://localhost:8080) | **ACTIVE** | Suggested plugins installed and initialized. |


