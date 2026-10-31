# ============================================================
# cloud-sql.tf — Managed MySQL Database (Cloud SQL)
# ============================================================
# Cloud SQL is Google's MANAGED database service.
# "Managed" means Google handles:
#   ✅ Patching & security updates
#   ✅ Automated backups
#   ✅ High availability failover
#   ✅ Disk encryption
#   ✅ Monitoring
#
# We just configure it — no database admin (DBA) needed.
#
# ARCHITECTURE:
#   ┌──────────────────┐         ┌──────────────────┐
#   │   PRIMARY DB     │  sync   │   STANDBY DB     │
#   │   (Zone A)       │ ──────> │   (Zone B)       │
#   │   Read + Write   │         │   Auto-failover  │
#   └──────────────────┘         └──────────────────┘
#
# If the primary fails, the standby takes over in <60 seconds.
# No data is lost because replication is SYNCHRONOUS.
# ============================================================


# ------------------------------------------------------------
# 1. CLOUD SQL INSTANCE (The Database Server)
# ------------------------------------------------------------
# This is the main database server. It hosts MySQL 8.0 and stores
# all customer data: orders, users, products, addresses.
# ------------------------------------------------------------
resource "google_sql_database_instance" "primary" {
  name = "${local.name_prefix}-db-${var.environment}"
  # Example: "northpoint-db-dev"

  # Database engine and version
  database_version = var.db_version   # "MYSQL_8_0"

  # Region: Hong Kong (PDPO — customer data stays here)
  region = var.region   # "asia-east2"

  # Deletion protection: prevents accidental deletion
  # Set to false for testing (so 'terraform destroy' works)
  # Set to true for production!
  deletion_protection = var.db_deletion_protection

  # This resource depends on the VPC peering connection being ready
  # (Cloud SQL needs the private network to be set up first)
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    # ---- MACHINE SIZE ----
    # How powerful the database server is (CPU + RAM)
    # Testing:    "db-f1-micro"        (shared CPU, 0.6GB RAM — cheapest)
    # Production: "db-custom-4-15360"  (4 vCPU, 15GB RAM — our design)
    tier = var.db_tier

    # ---- HIGH AVAILABILITY ----
    # "ZONAL"    = single zone (cheaper, ok for dev)
    # "REGIONAL" = two zones with automatic failover (production!)
    # When REGIONAL: a standby replica runs in a different zone.
    # If primary zone has an outage, standby is promoted automatically.
    availability_type = var.db_ha_enabled ? "REGIONAL" : "ZONAL"

    # ---- STORAGE ----
    disk_type       = "PD_SSD"              # SSD = fast (required for e-commerce)
    disk_size       = var.db_storage_size_gb # 10GB for testing, 100GB for production
    disk_autoresize = true                   # Automatically grow if we run out of space
    disk_autoresize_limit = 500              # Hard cap at 500GB (cost safety)

    # ---- NETWORK ----
    # CRITICAL: Private IP only — no public IP!
    # The database is ONLY accessible from within our VPC.
    # This means hackers cannot reach it from the internet.
    ip_configuration {
      ipv4_enabled    = false                               # ← NO public IP!
      private_network = google_compute_network.vpc.id       # Use our VPC
    }

    # ---- BACKUPS ----
    # Automated backups protect against data loss.
    # PITR (Point-In-Time Recovery) lets us restore to ANY SECOND
    # using the MySQL binary log.
    backup_configuration {
      enabled                        = var.db_backup_enabled  # true
      binary_log_enabled             = var.db_backup_enabled  # Required for PITR in MySQL
      # Note: For MySQL, binary_log_enabled IS the PITR mechanism
      # (point_in_time_recovery_enabled is only for PostgreSQL/SQL Server)

      start_time = "18:00"   # UTC = 02:00 HKT (lowest traffic time)

      # Keep 7 days of backups
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7       # Keep 7 daily backups
        retention_unit   = "COUNT"
      }
    }

    # ---- MAINTENANCE WINDOW ----
    # When Google can apply patches and updates
    # Set to Sunday 02:00 UTC (10:00 HKT) — low traffic
    maintenance_window {
      day          = 7    # Sunday (1=Monday, 7=Sunday)
      hour         = 2    # 02:00 UTC
      update_track = "stable"   # Use stable updates (not canary)
    }

    # ---- PERFORMANCE FLAGS ----
    # MySQL configuration flags for e-commerce workload
    database_flags {
      name  = "slow_query_log"
      value = "on"   # Log slow queries for performance debugging
    }
    database_flags {
      name  = "long_query_time"
      value = "2"    # Log queries taking longer than 2 seconds
    }
    database_flags {
      name  = "max_connections"
      value = "200"  # Max simultaneous database connections
    }

    # ---- LABELS ----
    user_labels = local.common_labels
  }
}


# ------------------------------------------------------------
# 2. DATABASE (Schema Inside the Instance)
# ------------------------------------------------------------
# The instance is the "server". The database is the "folder"
# inside it where our tables live. We can have multiple databases
# on one instance, but we only need one: "northpoint".
# ------------------------------------------------------------
resource "google_sql_database" "ecommerce" {
  name     = "northpoint"   # Database name our PHP app connects to
  instance = google_sql_database_instance.primary.name

  # Character set: utf8mb4 supports emoji and all languages
  # (important for Hong Kong — Traditional Chinese characters)
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}


# ------------------------------------------------------------
# 3. DATABASE USER (Login Credentials)
# ------------------------------------------------------------
# Create a dedicated user for the application.
# We DON'T use the root account — that's a security best practice.
# The password comes from Secret Manager (never hardcoded).
# ------------------------------------------------------------
resource "google_sql_user" "app_user" {
  name     = "northpoint_app"   # Username the PHP app uses
  instance = google_sql_database_instance.primary.name

  # Password from our terraform.tfvars (marked as sensitive)
  password = var.db_password

  # Connection policy
  host = "%"   # Allow connections from any host within the VPC
               # (safe because the DB has no public IP)
}

