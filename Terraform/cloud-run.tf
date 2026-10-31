# ============================================================
# cloud-run.tf — Serverless Container Hosting (The Store Itself)
# ============================================================
# Cloud Run is Google's SERVERLESS container platform.
# It runs our PHP e-commerce application (WooCommerce) inside
# Docker containers — without us managing any servers.
#
# "Serverless" means:
#   ✅ No VMs to create, patch, or restart
#   ✅ Auto-scales from 2 to 50 instances based on traffic
#   ✅ Auto-heals: if an instance crashes, a new one starts
#   ✅ Pay only for what you use (per-request + per-second billing)
#
# TRAFFIC FLOW:
#   Customer → Load Balancer → Cloud Armor (WAF) → Cloud Run → Cloud SQL
#
# AUTO-SCALING BEHAVIOUR:
#   Normal day (62 sessions/hr):  2 instances running
#   Campaign (620 sessions/hr):   15-20 instances (auto, ~15 seconds)
#   After campaign:               scales back down to 2
# ============================================================


# ------------------------------------------------------------
# 1. ARTIFACT REGISTRY (Container Image Storage)
# ------------------------------------------------------------
# Before Cloud Run can run our app, we need to store the Docker
# image somewhere. Artifact Registry is Google's container registry.
#
# Think of it as "Docker Hub but private and inside Google Cloud".
#
# The CI/CD pipeline (Cloud Build) pushes images here after building.
# Cloud Run pulls images from here when deploying.
# ------------------------------------------------------------
resource "google_artifact_registry_repository" "docker" {
  repository_id = "${local.name_prefix}-docker-${var.environment}"
  # Example: "northpoint-docker-dev"

  location = var.region   # asia-east2 (Hong Kong)
  format   = "DOCKER"     # Container images (not npm, maven, etc.)

  description = "Docker container images for Northpoint Living storefront"

  labels = local.common_labels

  # Clean up old images automatically to save storage costs
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10   # Keep the 10 most recent image versions
    }
  }
}


# ------------------------------------------------------------
# 2. CLOUD RUN SERVICE (The Running Application)
# ------------------------------------------------------------
# This is the CORE of our architecture — the actual running store.
# Each "instance" is a copy of our PHP app inside a Docker container.
# Multiple instances run simultaneously for high availability.
# ------------------------------------------------------------
resource "google_cloud_run_v2_service" "storefront" {
  name = "${local.name_prefix}-storefront-${var.environment}"
  # Example: "northpoint-storefront-dev"

  location = var.region   # asia-east2 (Hong Kong)

  # ---- INGRESS (Who Can Reach Cloud Run) ----
  # "INGRESS_TRAFFIC_ALL" = accept traffic from anywhere
  # In production with a load balancer, change to:
  # "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" (only via LB)
  ingress = "INGRESS_TRAFFIC_ALL"

  # ---- THE TEMPLATE ----
  # The template defines HOW each instance should be configured.
  # Every time Cloud Run creates a new instance, it uses this template.
  template {

    # ---- SERVICE ACCOUNT ----
    # Which identity this Cloud Run instance uses
    # (the one we created in iam.tf with limited permissions)
    service_account = google_service_account.cloud_run.email

    # ---- AUTO-SCALING ----
    # How many instances to run at any given time
    scaling {
      # Minimum instances ALWAYS running (even with zero traffic)
      # - 1 for dev (save money)
      # - 2 for production (one per zone = high availability)
      min_instance_count = var.min_instances

      # Maximum instances during traffic spikes
      # This is a COST SAFETY CAP — prevents runaway bills
      # - 5 for dev testing
      # - 50 for production (handles 10× campaign spikes)
      max_instance_count = var.max_instances
    }

    # ---- MAX CONCURRENT REQUESTS PER INSTANCE ----
    # How many simultaneous requests each instance handles
    # PHP-FPM typically handles 50-80 concurrent requests
    # Higher = fewer instances needed = lower cost
    max_instance_request_concurrency = var.cloud_run_concurrency   # 80

    # ---- TIMEOUT ----
    # Maximum time a single request can take before being killed
    # 60 seconds is generous for an e-commerce page load
    timeout = "60s"

    # ---- VPC ACCESS ----
    # Connect Cloud Run to our private VPC network
    # so it can reach Cloud SQL's private IP address
    vpc_access {
      connector = google_vpc_access_connector.connector.id

      # Only route traffic to private IP ranges through the VPC
      # (public internet traffic goes directly, not through VPC)
      egress = "PRIVATE_RANGES_ONLY"
    }

    # ---- CONTAINER CONFIGURATION ----
    # This defines the Docker container that runs our PHP app
    containers {
      name = "storefront"

      # ---- CONTAINER IMAGE ----
      # The Docker image to run. During initial setup, we use Google's
      # "hello" sample image. Replace with your real image after building.
      #
      # Real image format:
      # asia-east2-docker.pkg.dev/PROJECT_ID/northpoint-docker-dev/storefront:latest
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      # ---- PORT ----
      # The port our PHP app listens on inside the container
      ports {
        container_port = 8080   # Standard Cloud Run port
      }

      # ---- RESOURCES (CPU & MEMORY) ----
      # How much compute power each instance gets
      resources {
        limits = {
          cpu    = var.cloud_run_cpu      # "1" for dev, "2" for prod
          memory = var.cloud_run_memory   # "1Gi" for dev, "4Gi" for prod
        }

        # CPU allocation strategy:
        # true  = CPU only allocated during requests (cheaper, but cold starts)
        # false = CPU always allocated (more expensive, but instant response)
        # For e-commerce: false (customers expect instant page loads)
        cpu_idle = var.environment == "prod" ? false : true
      }

      # ---- ENVIRONMENT VARIABLES ----
      # Configuration values passed to the PHP application

      # Database connection: Host IP (private)
      env {
        name  = "DB_HOST"
        value = google_sql_database_instance.primary.private_ip_address
      }

      # Database connection: Database name
      env {
        name  = "DB_NAME"
        value = google_sql_database.ecommerce.name   # "northpoint"
      }

      # Database connection: Username
      env {
        name  = "DB_USER"
        value = google_sql_user.app_user.name   # "northpoint_app"
      }

      # Database connection: Port
      env {
        name  = "DB_PORT"
        value = "3306"   # MySQL default port
      }

      # Media storage: Which bucket to use for product images
      env {
        name  = "MEDIA_BUCKET"
        value = google_storage_bucket.product_media.name
      }

      # Media CDN URL: Where product images are served from
      env {
        name  = "MEDIA_URL"
        value = "https://storage.googleapis.com/${google_storage_bucket.product_media.name}"
      }

      # Application environment
      env {
        name  = "APP_ENV"
        value = var.environment   # "dev", "staging", or "prod"
      }

      # ---- SECRETS (From Secret Manager) ----
      # These are injected securely — never visible in logs or console

      # Database password (from secrets.tf)
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"   # Always use the latest version
          }
        }
      }

      # JWT secret for user authentication tokens
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.jwt_secret.secret_id
            version = "latest"
          }
        }
      }

      # Application secret key for encryption
      env {
        name = "APP_SECRET"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.app_secret.secret_id
            version = "latest"
          }
        }
      }

      # ---- STARTUP PROBE ----
      # Cloud Run waits for this to succeed before sending traffic.
      # If the health endpoint doesn't respond, the instance is
      # considered broken and replaced with a new one.
      startup_probe {
        http_get {
          path = var.uptime_check_path   # "/api/health"
          port = 8080
        }
        initial_delay_seconds = 5    # Wait 5 sec before first check
        period_seconds        = 3    # Check every 3 seconds
        failure_threshold     = 10   # Give up after 10 failures (30 sec total)
        timeout_seconds       = 3    # Each check times out after 3 sec
      }

      # ---- LIVENESS PROBE ----
      # Continuously checks if the running instance is healthy.
      # If it fails, Cloud Run kills and restarts the instance.
      liveness_probe {
        http_get {
          path = var.uptime_check_path   # "/api/health"
          port = 8080
        }
        period_seconds    = 30   # Check every 30 seconds
        failure_threshold = 3    # Restart after 3 consecutive failures
        timeout_seconds   = 5    # Each check times out after 5 sec
      }
    }
  }

  # ---- TRAFFIC ROUTING ----
  # Controls which version (revision) of the app receives traffic.
  # "LATEST" = always send 100% traffic to the newest deployment.
  # For blue-green deployments, you can split traffic between revisions.
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100   # 100% to latest revision
  }

  # Ignore changes to the container image — managed by CI/CD pipeline
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  labels = local.common_labels
}


# ------------------------------------------------------------
# 3. MAKE CLOUD RUN PUBLICLY ACCESSIBLE
# ------------------------------------------------------------
# By default, Cloud Run requires authentication to access.
# For a public e-commerce website, we need to allow unauthenticated
# (anonymous) access so customers can browse without logging in.
# ------------------------------------------------------------
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  name     = google_cloud_run_v2_service.storefront.name
  location = google_cloud_run_v2_service.storefront.location

  role   = "roles/run.invoker"
  member = "allUsers"   # ← Anyone can access (public website)
}

