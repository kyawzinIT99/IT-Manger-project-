# 🚀 Northpoint Living — Terraform Setup Guide
## Step-by-Step: From Zero to Deployed Infrastructure

> **Workflow:** Install tools → Authenticate → `terraform apply` (test) → Push to Git → `terraform destroy` (clean up)
>
> After testing, all infrastructure is destroyed with one command. The code stays safe in Git for production deployment later.

---

## Table of Contents

1. [Prerequisites — Install Tools](#step-1-install-terraform)
2. [GCP Project Setup](#step-2-create-gcp-project)
3. [Authenticate with Google Cloud](#step-3-authenticate-gcloud)
4. [Configure Terraform Variables](#step-4-configure-variables)
5. [Deploy Infrastructure](#step-5-deploy)
6. [Verify Everything Works](#step-6-verify)
7. [Push to Git](#step-7-push-to-git)
8. [Destroy Everything](#step-8-destroy)
9. [Troubleshooting](#troubleshooting)

---

## Step 1: Install Terraform

### macOS (using Homebrew)

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Terraform
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verify installation
terraform --version
# Expected output: Terraform v1.x.x
```

### Verify Terraform Works

```bash
# Check terraform is in your PATH
which terraform
# Expected: /opt/homebrew/bin/terraform

# Quick test
terraform -help
```

---

## Step 2: Install Google Cloud CLI (gcloud)

### macOS (using Homebrew)

```bash
# Install Google Cloud SDK
brew install --cask google-cloud-sdk

# Verify installation
gcloud --version
# Expected output:
# Google Cloud SDK x.x.x
# bq x.x.x
# core x.x.x
# gsutil x.x.x
```

### If Homebrew method doesn't work

```bash
# Download and install manually
curl https://sdk.cloud.google.com | bash

# Restart terminal, then verify
gcloud --version
```

---

## Step 3: Authenticate with Google Cloud

### 3a. Login to your Google Account

```bash
# This opens a browser window — sign in with your Google account
gcloud auth login

# Set application default credentials (Terraform uses this)
gcloud auth application-default login
```

### 3b. Create or Select GCP Project

```bash
# Option A: Create a NEW project
gcloud projects create northpoint-living --name="Northpoint Living"

# Option B: Use an EXISTING project
gcloud projects list                    # See all your projects
gcloud config set project YOUR_PROJECT_ID   # Select one
```

### 3c. Enable Required APIs

```bash
# Set your project ID (replace with yours)
export PROJECT_ID="northpoint-living"
gcloud config set project $PROJECT_ID

# Enable all required APIs (run these one by one)
gcloud services enable compute.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable vpcaccess.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

> ⚠️ **Important:** You need a **Billing Account** linked to the project.
> Go to: https://console.cloud.google.com/billing
> Link a billing account to your project. You can use the GCP Free Trial ($300 credit).

### 3d. Verify Authentication

```bash
# Check you're authenticated
gcloud auth list
# Should show your email with an asterisk (*)

# Check your project is set
gcloud config get-value project
# Should output: northpoint-living (or your project ID)
```

---

## Step 4: Configure Terraform Variables

### 4a. Copy the example variables file

```bash
cd "/Users/berry/Antigravity/IT Manager project /Terraform"

# Create your local variables file from the example
cp terraform.tfvars.example terraform.tfvars
```

### 4b. Edit terraform.tfvars with YOUR values

```bash
# Open in your editor
nano terraform.tfvars
# or
code terraform.tfvars
```

Update these values:

```hcl
# terraform.tfvars — YOUR values here
project_id    = "northpoint-living"       # Your GCP project ID
region        = "asia-east2"              # Hong Kong
environment   = "dev"                     # dev for testing, prod for live

# Database
db_password   = "YourStr0ng!Passw0rd"     # Change this!
db_tier       = "db-f1-micro"             # Use small tier for TESTING
                                          # Change to "db-custom-4-15360" for PRODUCTION

# Cloud Run
min_instances = 1                          # 1 for testing (save money)
max_instances = 5                          # 5 for testing
image_tag     = "latest"

# Domain (optional — skip for testing)
domain_name   = ""
```

> 💡 **For testing:** Use small/cheap tiers. Change to production sizes only when deploying for real.

---

## Step 5: Deploy Infrastructure

### 5a. Initialise Terraform

```bash
cd "/Users/berry/Antigravity/IT Manager project /Terraform"

# Download providers and initialise
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Installing hashicorp/google v6.x.x...
- Installing hashicorp/random v3.x.x...

Terraform has been successfully initialized!
```

### 5b. Preview What Will Be Created

```bash
# See what Terraform WILL create (nothing built yet)
terraform plan
```

This shows you every resource that will be created. Review it carefully.

### 5c. Apply — Build Everything

```bash
# Build all infrastructure (type 'yes' when prompted)
terraform apply
```

> ⏱️ **This takes 10–15 minutes.** Cloud SQL HA is the slowest (~8 min).

Expected output:
```
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:
  cloud_run_url     = "https://northpoint-storefront-xxxxx-de.a.run.app"
  cloud_sql_ip      = "10.x.x.x"
  storage_bucket    = "northpoint-media-xxxxx"
  load_balancer_ip  = "34.x.x.x"
```

---

## Step 6: Verify Everything Works

### 6a. Check Cloud Run

```bash
# Test the Cloud Run service
curl $(terraform output -raw cloud_run_url)/api/health
# Expected: {"status":"healthy"}
```

### 6b. Check Cloud SQL

```bash
# Verify database is running
gcloud sql instances describe northpoint-db-dev --format="value(state)"
# Expected: RUNNABLE
```

### 6c. Check in GCP Console

Open these URLs in your browser:
- **Cloud Run:** https://console.cloud.google.com/run
- **Cloud SQL:** https://console.cloud.google.com/sql
- **Storage:** https://console.cloud.google.com/storage
- **VPC:** https://console.cloud.google.com/networking/networks
- **Monitoring:** https://console.cloud.google.com/monitoring

### 6d. List All Created Resources

```bash
# See what Terraform is managing
terraform state list
```

---

## Step 7: Push to Git

### 7a. Initialise Git (if not already)

```bash
cd "/Users/berry/Antigravity/IT Manager project /Terraform"

git init
git add .
git commit -m "feat: Northpoint Living GCP infrastructure — Terraform"
```

### 7b. Push to GitHub/GitLab

```bash
# Create a repo on GitHub first, then:
git remote add origin https://github.com/YOUR_USERNAME/northpoint-terraform.git
git branch -M main
git push -u origin main
```

> ⚠️ The `.gitignore` file is already configured to **exclude sensitive files**:
> - `terraform.tfvars` (your passwords)
> - `*.tfstate` (infrastructure state)
> - `.terraform/` (provider binaries)

---

## Step 8: Destroy Everything (Clean Up)

### After testing is complete, remove ALL infrastructure:

```bash
cd "/Users/berry/Antigravity/IT Manager project /Terraform"

# Preview what will be destroyed
terraform plan -destroy

# Destroy everything (type 'yes' when prompted)
terraform destroy
```

> ⏱️ **This takes 5–10 minutes.** Cloud SQL takes longest to delete.

Expected output:
```
Destroy complete! Resources: 25 destroyed.
```

### Verify destruction

```bash
# Confirm nothing is left running
gcloud sql instances list
gcloud run services list --region=asia-east2
gcloud compute networks list
```

All should return empty or show no resources.

---

## Troubleshooting

### ❌ "Error: Required APIs not enabled"

```bash
# Re-run the API enable commands from Step 3c
gcloud services enable MISSING_API.googleapis.com
```

### ❌ "Error: Billing account not linked"

```bash
# Link billing account
gcloud billing accounts list
gcloud billing projects link PROJECT_ID --billing-account=BILLING_ACCOUNT_ID
```

### ❌ "Error: Permission denied"

```bash
# Make sure you're the owner of the project
gcloud projects get-iam-policy PROJECT_ID --filter="bindings.role:roles/owner"

# Re-authenticate
gcloud auth login
gcloud auth application-default login
```

### ❌ "Error: Resource already exists"

```bash
# If a previous destroy failed, import the resource
terraform import google_compute_network.vpc projects/PROJECT_ID/global/networks/northpoint-vpc

# Or force destroy
terraform destroy -auto-approve
```

### ❌ Cloud SQL takes too long to delete

Cloud SQL instances with `deletion_protection = true` cannot be destroyed. For testing:

```bash
# Disable deletion protection first
gcloud sql instances patch northpoint-db-dev --no-deletion-protection

# Then retry
terraform destroy
```

---

## 📋 Quick Reference — All Commands

```bash
# === SETUP ===
brew install hashicorp/tap/terraform
brew install --cask google-cloud-sdk
gcloud auth login
gcloud auth application-default login

# === DEPLOY ===
cd "/Users/berry/Antigravity/IT Manager project /Terraform"
terraform init          # Download providers
terraform plan          # Preview changes
terraform apply         # Build everything

# === VERIFY ===
terraform output        # Show URLs and IPs
terraform state list    # Show all resources

# === CLEAN UP ===
terraform destroy       # Delete EVERYTHING

# === GIT ===
git add .
git commit -m "infrastructure update"
git push origin main
```

---

> 💡 **Remember:** The Terraform code is your "blueprint". You can destroy and rebuild the exact same infrastructure anytime with `terraform apply`. That's the power of Infrastructure as Code.
