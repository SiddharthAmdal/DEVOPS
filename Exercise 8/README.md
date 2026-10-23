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

- [x] **Phase 2: Jenkins Job Configuration & SCM Integration**
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

---

## Phase 2: Jenkins Job Configuration & SCM Integration

### 1. Freestyle Project Architecture

In Jenkins, a **Freestyle Project** is a configurable job model designed for straightforward build and automation workflows:
* **General**: Provides metadata, build descriptions, and concurrency controls.
* **Source Code Management (SCM)**: Integrates directly with Git repositories, polling for changes or responding to commit webhooks.
* **Build Triggers**: Supports manual dispatch (`Build Now`), scheduled cron triggers (`H/15 * * * *`), or SCM polling.
* **Build Steps**: Sequentially executes commands (e.g., Execute shell, Invoke Gradle/Maven).
* **Post-build Actions**: Archives build artifacts, records test results, or triggers downstream builds.

---

### 2. Job Configuration XML (`job_config.xml`)

Jenkins serializes all job definitions as XML:

```xml
<?xml version='1.1' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Hello World! Jenkins job.</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <scm class="hudson.plugins.git.GitSCM" plugin="git">
    <configVersion>2</configVersion>
    <userRemoteConfigs>
      <hudson.plugins.git.UserRemoteConfig>
        <url>https://github.com/SiddharthAmdal/DEVOPS.git</url>
      </hudson.plugins.git.UserRemoteConfig>
    </userRemoteConfigs>
    <branches>
      <hudson.plugins.git.BranchSpec>
        <name>*/main</name>
      </hudson.plugins.git.BranchSpec>
    </branches>
    <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
    <submoduleCfg class="empty-list"/>
    <extensions/>
  </scm>
  <canRoam>true</canRoam>
  <disabled>false</disabled>
  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers/>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>if [ -f "Exercise 8/devops-sample-code/hello-world.sh" ]; then
    sh "Exercise 8/devops-sample-code/hello-world.sh"
elif [ -f "hello-world.sh" ]; then
    sh hello-world.sh
else
    echo "Hello, Jenkins!"
fi</command>
      <configuredLocalRules/>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
```

---

### 3. Automated Job Provisioning Script (`create-job.sh`)

To eliminate manual configuration errors, [`create-job.sh`](./create-job.sh) authenticates against the Jenkins REST API, fetches CSRF crumb tokens and session cookies, and creates or updates the `HelloWorld` job:

```bash
./"Exercise 8/create-job.sh"
```

#### Execution Output:
```text
=== [1/4] Retrieving Admin Password from Jenkins Container ===
Password retrieved successfully.
=== [2/4] Fetching CSRF Crumb & Session Cookie ===
Obtained CSRF Crumb (Jenkins-Crumb).
=== [3/4] Creating/Updating Job 'HelloWorld' ===
Job 'HelloWorld' created successfully.

=== [4/4] Verification ===
Job URL: http://localhost:8080/job/HelloWorld
```

---

### 4. Manual Web UI Setup Guide

If you prefer configuring the job through the Jenkins graphical interface:

1. **Create New Item**:
   - Open [http://localhost:8080](http://localhost:8080).
   - In the left sidebar, click **New Item**.
   - Enter item name: **`HelloWorld`**.
   - Select **Freestyle project** and click **OK**.

2. **General Tab**:
   - Add description: `Hello World! Jenkins job.`.

3. **Source Code Management**:
   - Select **Git**.
   - Set Repository URL: `https://github.com/SiddharthAmdal/DEVOPS.git`.
   - Set Branch Specifier: `*/main`.

4. **Build Steps**:
   - Click **Add build step** $\rightarrow$ select **Execute shell**.
   - In the Command text area, enter:
     ```bash
     sh hello-world.sh
     ```
     *(or `sh "Exercise 8/devops-sample-code/hello-world.sh"`)*

5. **Save**:
   - Click **Save** at the bottom of the page.

