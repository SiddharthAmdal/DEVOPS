# Exercise 8: Creating "Hello World" Jenkins Job

## Objective
The objective of this exercise is to understand how Jenkins interacts with version control systems (Git/GitHub) and automates script execution through **Freestyle Projects**.

In this exercise, you will:
1. Create and configure an automated execution script ([`hello-world.sh`](./devops-sample-code/hello-world.sh)) inside the project directory [`Exercise 8/devops-sample-code/`](./devops-sample-code/).
2. Understand Jenkins **Freestyle Jobs** vs. **Pipeline Projects**.
3. Configure a Jenkins Freestyle job named **`HelloWorld`** with Git Source Code Management (SCM).
4. Define build steps to execute shell scripts within the Jenkins container workspace (`/var/jenkins_home/workspace/HelloWorld`).
5. Trigger builds and inspect the live console output to verify `Finished: SUCCESS`.

---

## Architectural Workflow: SCM to Job Execution

```
+-----------------------------------------------------------------------------------+
|                           Git Repository (GitHub / Local)                         |
|                 Path: Exercise 8/devops-sample-code/hello-world.sh                |
+-----------------------------------------------------------------------------------+
                                          |
                                          | 1. SCM Clone / Checkout
                                          v
                    +------------------------------------------+
                    |             Jenkins Controller           |
                    |             (Port 8080 Web UI)           |
                    |   Job: "HelloWorld" (Freestyle Project)  |
                    +------------------------------------------+
                                          |
                                          | 2. Allocates Executor
                                          v
                    +------------------------------------------+
                    |            Jenkins Workspace             |
                    |   /var/jenkins_home/workspace/HelloWorld |
                    +------------------------------------------+
                                          |
                                          | 3. Executes Shell Step:
                                          |    sh hello-world.sh
                                          v
                    +------------------------------------------+
                    |           Build Console Output           |
                    |   + echo 'Hello, Jenkins!'               |
                    |   Hello, Jenkins!                        |
                    |   Finished: SUCCESS                      |
                    +------------------------------------------+
```

---

## Exercise Implementation Roadmap

- [x] **Phase 1: Script Creation & Workspace Directory Setup**
  - Establish `Exercise 8/devops-sample-code/` directory structure.
  - Create the bash execution script ([`hello-world.sh`](./devops-sample-code/hello-world.sh)).
  - Configure executable permissions (`chmod +x hello-world.sh`).
  - Verify local script execution.

- [ ] **Phase 2: Jenkins Job Configuration & SCM Integration**
  - Define job configuration XML ([`job_config.xml`](./job_config.xml)) for the `HelloWorld` Freestyle project.
  - Configure Git Source Code Management (SCM) targeting repository branch `main`.
  - Add build step **Execute shell** to run `hello-world.sh`.
  - Automate job creation in the running Jenkins instance ([`create-job.sh`](./create-job.sh)).

- [ ] **Phase 3: Job Execution, Console Output Validation & UI Proof**
  - Trigger build execution (**Build Now**) via Jenkins API / Web UI.
  - Monitor build queue and executor progress.
  - Verify build logs in **Console Output** for `Hello, Jenkins!` and status `SUCCESS`.
  - Capture visual UI proof and screenshots.

---

## Phase 1: Script Creation & Workspace Directory Setup

### 1. Script Implementation (`hello-world.sh`)

Located in [`Exercise 8/devops-sample-code/hello-world.sh`](./devops-sample-code/hello-world.sh):

```bash
#!/bin/bash
echo "Hello, Jenkins!"
```

### 2. Permissions & Local Verification

Make the script executable:
```bash
chmod +x "Exercise 8/devops-sample-code/hello-world.sh"
```

Execute locally:
```bash
./"Exercise 8/devops-sample-code/hello-world.sh"
```

#### Output:
```text
Hello, Jenkins!
```
