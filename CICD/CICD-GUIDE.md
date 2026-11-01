# 🔄 Northpoint Living — CI/CD Pipeline Guide (GitHub Actions + Local Runner)

All CI/CD files and local test outputs are stored inside `/Users/berry/Antigravity/IT Manager project /CICD/` and `.github/workflows/northpoint-ci.yml`.

---

## 🏗️ 1. How CI/CD Connects Your Entire DevOps Stack

```text
💻 YOUR MACBOOK WORKSTATION
 │
 │  Step 1 (Local Pre-Check):
 │  ./CICD/run-local-cicd-pipeline.sh
 │  └──► Saves report in: ./CICD/test-outputs/cicd-pipeline-report.txt
 │
 │  Step 2 (Push to GitHub):
 │  git push origin main
 ▼
🐙 GITHUB ACTIONS CLOUD RUNNER (.github/workflows/northpoint-ci.yml)
 │
 ├──► 🏗️ Job 1 (terraform-ci)     : Runs `terraform init` & `terraform validate`
 ├──► 🤖 Job 2 (ansible-ci)       : Runs `ansible-playbook --syntax-check` on Lessons 00–10
 ├──► ☸️ Job 3 (kubernetes-ci)    : Validates all YAML manifests in `kubernates/`
 └──► 🐳 Job 4 (docker-build-test): Builds `northpoint-storefront:ci` & curls `/api/health` + `/metrics`
```

---

## 📂 2. Key Files Created

1. **[`.github/workflows/northpoint-ci.yml`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/.github/workflows/northpoint-ci.yml)** — The official GitHub Actions workflow file that GitHub automatically runs on every `git push`.
2. **[`CICD/run-local-cicd-pipeline.sh`](file:///Users/berry/Antigravity/IT%20Manager%20project%20/CICD/run-local-cicd-pipeline.sh)** — Runs all 4 stages locally on your MacBook and writes the report to `CICD/test-outputs/cicd-pipeline-report.txt`.

---

## 🚀 3. Step-by-Step Commands to Run Your CI/CD Pipeline

### Step 1: Run the Local CI/CD Pipeline on Your MacBook
```bash
cd "/Users/berry/Antigravity/IT Manager project /CICD"
chmod +x run-local-cicd-pipeline.sh
./run-local-cicd-pipeline.sh
```
Check your saved test report:
```bash
cat test-outputs/cicd-pipeline-report.txt
```

### Step 2: Push to GitHub to Trigger Live GitHub Actions CI/CD!
```bash
cd "/Users/berry/Antigravity/IT Manager project "
git add .
git commit -m "Add GitHub Actions 4-stage CI/CD pipeline and Nginx Load Balancer"
git push origin main
```

### Step 3: Watch Your Pipeline Run Live on GitHub!
Open your browser and visit your GitHub Actions tab:
👉 **https://github.com/kyawzinIT99/IT-Manger-project-/actions**

You will see **"Northpoint Living — DevOps CI/CD Pipeline"** running all 4 jobs (`Terraform`, `Ansible`, `Kubernetes`, and `Docker Build & Live API Test`) and turning **Green ✅**!

