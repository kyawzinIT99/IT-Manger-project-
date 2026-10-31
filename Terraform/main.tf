# ============================================================
# main.tf — The Entry Point of Our Terraform Project
# ============================================================
# This file does THREE things:
#   1. Declares what version of Terraform we need
#   2. Configures the Google Cloud provider (which cloud to talk to)
#   3. Sets up where to store Terraform's "state" (memory of what exists)
#
# Think of this file as the "settings page" for the entire project.
# ============================================================


# ------------------------------------------------------------
# 1. TERRAFORM SETTINGS
# ------------------------------------------------------------
# Tell Terraform which version to use and which providers (plugins)
# to download. Providers are how Terraform talks to cloud services.
# ------------------------------------------------------------
terraform {
  # Minimum Terraform version required
  required_version = ">= 1.5.0"

  # Providers = plugins that let Terraform manage cloud resources
  required_providers {
    # Google Cloud provider — lets us create GCP resources
    google = {
      source  = "hashicorp/google"   # Official Google provider by HashiCorp
      version = "~> 6.0"            # Use version 6.x (latest stable)
    }

    # Random provider — generates random strings for unique names
    # (e.g., database passwords, bucket name suffixes)
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # ---- STATE BACKEND (where Terraform remembers what it built) ----
  # For TESTING: state is stored locally (on your laptop).
  # For PRODUCTION: uncomment the 'backend "gcs"' block below
  # to store state in a Google Cloud Storage bucket (shared, safe, locked).
  #
  # backend "gcs" {
  #   bucket = "northpoint-terraform-state"   # Create this bucket first!
  #   prefix = "terraform/state"
  # }
}


# ------------------------------------------------------------
# 2. GOOGLE CLOUD PROVIDER CONFIGURATION
# ------------------------------------------------------------
# This tells Terraform:
#   - Which GCP project to use
#   - Which region to deploy in (asia-east2 = Hong Kong)
#
# Authentication: Terraform uses the credentials from
# 'gcloud auth application-default login' (Step 3 in SETUP-GUIDE.md)
# ------------------------------------------------------------
provider "google" {
  project = var.project_id   # Your GCP project ID (set in terraform.tfvars)
  region  = var.region        # Default region: "asia-east2" (Hong Kong)
}


# ------------------------------------------------------------
# 3. RANDOM SUFFIX GENERATOR
# ------------------------------------------------------------
# GCP resource names must be globally unique (e.g., storage buckets).
# This generates a random 4-character suffix like "a1b2" to append
# to resource names, avoiding conflicts with other GCP users.
#
# Example: "northpoint-media" becomes "northpoint-media-a1b2"
# ------------------------------------------------------------
resource "random_id" "suffix" {
  byte_length = 2   # Generates 4 hex characters (2 bytes = 4 hex chars)
}


# ------------------------------------------------------------
# 4. LOCAL VALUES (Computed Variables)
# ------------------------------------------------------------
# These are "shortcuts" — values computed from other variables.
# We use them throughout other .tf files to keep names consistent.
# ------------------------------------------------------------
locals {
  # Project naming convention: "northpoint-{resource}-{environment}"
  # Example: "northpoint-db-dev" or "northpoint-db-prod"
  name_prefix = "northpoint"

  # Unique suffix for globally-unique resource names
  suffix = random_id.suffix.hex   # e.g., "a1b2"

  # Common labels applied to ALL resources (for cost tracking & organisation)
  common_labels = {
    project     = "northpoint-living"
    environment = var.environment       # "dev" or "prod"
    managed_by  = "terraform"           # So people know not to edit manually
    client      = "northpoint"
  }
}

