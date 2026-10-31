# ============================================================
# iam.tf — Identity & Access Management (Who Can Do What)
# ============================================================
# IAM controls PERMISSIONS in Google Cloud.
#
# Instead of using your personal Google account to run everything,
# we create a "Service Account" — a special robot account that
# only has the exact permissions it needs. Nothing more.
#
# This is called the "Principle of Least Privilege":
#   - Cloud Run gets permission to read secrets and access the DB
#   - Cloud Run does NOT get permission to delete the database
#   - Cloud Build gets permission to deploy, but not to read secrets
#
# WHY: If a hacker compromises Cloud Run, they can only do what
#       Cloud Run is allowed to do — they can't wipe your database.
# ============================================================


# ------------------------------------------------------------
# 1. SERVICE ACCOUNT FOR CLOUD RUN
# ------------------------------------------------------------
# This is the identity that our Cloud Run service uses.
# When Cloud Run needs to access Cloud SQL or read secrets,
# it authenticates as this service account.
# ------------------------------------------------------------
resource "google_service_account" "cloud_run" {
  account_id = "${local.name_prefix}-run-${var.environment}"
  # Example: "northpoint-run-dev@project.iam.gserviceaccount.com"

  display_name = "Northpoint Cloud Run Service Account (${var.environment})"
  description  = "Service account for the Northpoint Living storefront Cloud Run service"

  project = var.project_id
}


# ------------------------------------------------------------
# 2. PERMISSIONS FOR CLOUD RUN
# ------------------------------------------------------------
# Each "google_project_iam_member" gives ONE specific permission
# to the Cloud Run service account. We grant only what's needed.
# ------------------------------------------------------------

# Permission: Connect to Cloud SQL database
# Without this, Cloud Run cannot reach the database at all
resource "google_project_iam_member" "cloud_run_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  # This role allows: connect to Cloud SQL instances
  # This role does NOT allow: create/delete databases, change settings

  member = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Permission: Read secrets from Secret Manager
# Cloud Run needs to read the database password and JWT secret
resource "google_project_iam_member" "cloud_run_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  # This role allows: read secret values
  # This role does NOT allow: create/delete/modify secrets

  member = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Permission: Read/Write to Cloud Storage
# Cloud Run needs to upload/serve product images from the media bucket
resource "google_project_iam_member" "cloud_run_storage" {
  project = var.project_id
  role    = "roles/storage.objectUser"
  # This role allows: read, create, and delete objects in storage buckets
  # This role does NOT allow: create/delete buckets themselves

  member = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Permission: Write logs to Cloud Logging
# Cloud Run sends application logs here (errors, requests, etc.)
resource "google_project_iam_member" "cloud_run_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  # This role allows: write log entries
  # This role does NOT allow: read/delete logs

  member = "serviceAccount:${google_service_account.cloud_run.email}"
}

# Permission: Write metrics to Cloud Monitoring
# Cloud Run sends performance metrics (CPU, memory, request count)
resource "google_project_iam_member" "cloud_run_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  # This role allows: write custom metrics
  # This role does NOT allow: create alerts, read metrics

  member = "serviceAccount:${google_service_account.cloud_run.email}"
}


# ------------------------------------------------------------
# 3. SERVICE ACCOUNT FOR CLOUD BUILD (CI/CD)
# ------------------------------------------------------------
# Cloud Build is the CI/CD system that automatically deploys
# new versions of the app when code is pushed to Git.
# It needs permission to build containers and update Cloud Run.
# ------------------------------------------------------------
resource "google_service_account" "cloud_build" {
  account_id = "${local.name_prefix}-build-${var.environment}"
  # Example: "northpoint-build-dev@project.iam.gserviceaccount.com"

  display_name = "Northpoint Cloud Build Service Account (${var.environment})"
  description  = "Service account for CI/CD pipeline — builds and deploys the storefront"

  project = var.project_id
}

# Permission: Deploy to Cloud Run
resource "google_project_iam_member" "cloud_build_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  # This role allows: create/update/delete Cloud Run services
  # Needed so Cloud Build can deploy new versions

  member = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Permission: Push container images to Artifact Registry
resource "google_project_iam_member" "cloud_build_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  # This role allows: push/pull container images
  # Cloud Build pushes the built Docker image here

  member = "serviceAccount:${google_service_account.cloud_build.email}"
}

# Permission: Act as the Cloud Run service account
# Cloud Build needs this to assign the service account to Cloud Run during deployment
resource "google_project_iam_member" "cloud_build_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"

  member = "serviceAccount:${google_service_account.cloud_build.email}"
}

