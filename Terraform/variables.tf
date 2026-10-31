# ============================================================
# variables.tf — All Input Variables (The Knobs and Dials)
# ============================================================
# Variables let you change settings WITHOUT editing the code.
# Think of them as a form you fill out:
#   - terraform.tfvars        = YOUR answers (private, not in Git)
#   - terraform.tfvars.example = The blank form (safe to share)
#
# Each variable below has:
#   - description: What it does (human-readable)
#   - type:        What kind of value it expects
#   - default:     What value to use if you don't specify one
# ============================================================


# ========================
# PROJECT SETTINGS
# ========================

variable "project_id" {
  description = "Your Google Cloud Project ID (e.g., 'northpoint-living'). Find it at https://console.cloud.google.com"
  type        = string
  # No default — you MUST set this in terraform.tfvars
}

variable "region" {
  description = "GCP region to deploy in. asia-east2 = Hong Kong (for PDPO data residency compliance)"
  type        = string
  default     = "asia-east2"   # Hong Kong — closest to the client
}

variable "environment" {
  description = "Environment name: 'dev' for testing, 'staging' for pre-production, 'prod' for live"
  type        = string
  default     = "dev"

  # Only allow these specific values
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be 'dev', 'staging', or 'prod'."
  }
}


# ========================
# CLOUD RUN (Website Hosting)
# ========================

variable "min_instances" {
  description = "Minimum Cloud Run instances always running. Use 1 for dev (save money), 2 for prod (high availability — one per zone)"
  type        = number
  default     = 1   # Override to 2 for production!
}

variable "max_instances" {
  description = "Maximum Cloud Run instances during traffic spikes. This is a cost safety cap — prevents runaway scaling bills"
  type        = number
  default     = 10   # Override to 50 for production!
}

variable "cloud_run_cpu" {
  description = "vCPU allocated per Cloud Run instance. '1' is fine for dev, '2' for production with concurrent requests"
  type        = string
  default     = "1"
}

variable "cloud_run_memory" {
  description = "Memory (RAM) per Cloud Run instance. PHP apps typically need 512Mi–4Gi depending on plugins"
  type        = string
  default     = "1Gi"   # Override to "4Gi" for production
}

variable "cloud_run_concurrency" {
  description = "Max concurrent requests per instance. Higher = fewer instances needed. PHP-FPM typically handles 50-80"
  type        = number
  default     = 80
}

variable "image_tag" {
  description = "Docker image tag to deploy. 'latest' for dev, specific commit SHA for production (e.g., 'abc123f')"
  type        = string
  default     = "latest"
}


# ========================
# CLOUD SQL (Database)
# ========================

variable "db_tier" {
  description = <<-EOT
    Cloud SQL machine type. This determines CPU and RAM for the database.
    - Testing:    "db-f1-micro"          (shared core, 0.6GB — FREE TIER eligible)
    - Small prod: "db-custom-2-7680"     (2 vCPU, 7.5GB RAM)
    - Our design: "db-custom-4-15360"    (4 vCPU, 15GB RAM — as specified in submission)
  EOT
  type        = string
  default     = "db-f1-micro"   # Small for testing — saves ~$500/month!
}

variable "db_password" {
  description = "Password for the database 'northpoint' user. Use a strong password! Never commit this to Git"
  type        = string
  sensitive   = true   # ← Terraform will HIDE this value in all output/logs
  # No default — you MUST set this in terraform.tfvars
}

variable "db_version" {
  description = "MySQL version for Cloud SQL. Use 8.0 for best compatibility with modern PHP frameworks"
  type        = string
  default     = "MYSQL_8_0"
}

variable "db_ha_enabled" {
  description = <<-EOT
    Enable High Availability (HA) for Cloud SQL.
    - false = Single zone (cheaper, for testing)
    - true  = Multi-zone with auto-failover (production — doubles the DB cost but provides zero-downtime failover)
  EOT
  type        = bool
  default     = false   # Override to true for production!
}

variable "db_storage_size_gb" {
  description = "Initial storage size in GB for the database. Auto-grows as needed. 10GB is fine for testing"
  type        = number
  default     = 10   # Override to 100 for production
}

variable "db_backup_enabled" {
  description = "Enable automated daily backups and point-in-time recovery (PITR). Always true in production"
  type        = bool
  default     = true
}

variable "db_deletion_protection" {
  description = <<-EOT
    Prevent accidental deletion of the database.
    - false = Can be destroyed with 'terraform destroy' (needed for testing)
    - true  = Must manually disable before destruction (production safety)
  EOT
  type        = bool
  default     = false   # Override to true for production!
}


# ========================
# CLOUD STORAGE (Product Media)
# ========================

variable "storage_location" {
  description = "Location for Cloud Storage bucket. 'ASIA-EAST2' = Hong Kong (single region, lowest cost for our data residency requirement)"
  type        = string
  default     = "ASIA-EAST2"
}

variable "storage_class" {
  description = "Storage class: 'STANDARD' for frequently accessed media, 'NEARLINE' for backups (cheaper but access fees)"
  type        = string
  default     = "STANDARD"
}


# ========================
# CLOUD ARMOR (WAF / Security)
# ========================

variable "enable_cloud_armor" {
  description = "Enable Cloud Armor WAF (Web Application Firewall). Protects against DDoS, SQL injection, XSS attacks"
  type        = bool
  default     = true
}

variable "rate_limit_threshold" {
  description = "Maximum requests per minute per IP address. Blocks IPs that exceed this (bot protection). 100 is reasonable for e-commerce"
  type        = number
  default     = 100
}


# ========================
# MONITORING & ALERTS
# ========================

variable "alert_email" {
  description = "Email address to receive monitoring alerts (e.g., 'devops@visibleone.com'). Leave empty to skip alert setup"
  type        = string
  default     = ""
}

variable "uptime_check_path" {
  description = "URL path for uptime monitoring checks. Should be a lightweight health endpoint"
  type        = string
  default     = "/api/health"
}


# ========================
# DOMAIN & SSL (Optional)
# ========================

variable "domain_name" {
  description = "Custom domain name (e.g., 'northpointliving.com'). Leave empty to use the default Cloud Run URL for testing"
  type        = string
  default     = ""   # Set this when you have a real domain
}

