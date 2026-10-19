# Exercise 7: Introduction to Continuous Integration (CI) and Jenkins Installation

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

- [ ] **Phase 2: Jenkins Containerization, Volume Persistence & Port Orchestration**
  - Create automated deployment runner ([`install-jenkins.sh`](./install-jenkins.sh)) targeting `jenkins/jenkins:lts`.
  - Configure port forwarding for Web Management (`8080:8080`) and Agent JNLP communication (`50000:50000`).
  - Attach Docker named volume `jenkins_home` for persistent configurations and job history.
  - Implement security token extraction utility ([`get-admin-password.sh`](./get-admin-password.sh)).
  - Provide teardown and volume management script ([`cleanup.sh`](./cleanup.sh)).

- [ ] **Phase 3: Initialization, Verification & Browser Workflow Validation**
  - Launch Jenkins locally and verify container runtime health.
  - Retrieve the active initial administrator password from `/var/jenkins_home/secrets/initialAdminPassword`.
  - Validate the "Unlock Jenkins" administrative authentication gate.
  - Verify suggested plugin installation and main dashboard accessibility (`Welcome to Jenkins!`).
