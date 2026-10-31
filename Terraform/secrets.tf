# ============================================================
# secrets.tf — Secret Manager (Secure Password Storage)
# ============================================================
# Secret Manager is a Google Cloud service that securely stores
# sensitive values like database passwords, API keys, and tokens.
#
# WHY NOT just use environment variables?
#   - Env vars are visible in the GCP Console to anyone with access
#   - Env vars are logged in some deployment tools
#   - Secret Manager encrypts values, controls who can read them,
#     and keeps an audit trail of every access
#
# HOW IT WORKS:
#   1. We create a "secret" (a named container)
#   2. We add a "version" (the actual password value)
#   3. Cloud Run reads the secret at startup via its service account
#   4. The password never appears in Terraform output, logs, or console
# ============================================================


# ------------------------------------------------------------
# 1. DATABASE PASSWORD SECRET
# ------------------------------------------------------------
# Stores the MySQL root password securely.
# Cloud Run reads this at startup to connect to Cloud SQL.
# ------------------------------------------------------------

# Create the secret container (the "envelope")
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${local.name_prefix}-db-password-${var.environment}"
  # Example: "northpoint-db-password-dev"

  # Where to replicate the secret
  # Using our project region (Hong Kong) for data residency compliance
  replication {
    user_managed {
      replicas {
        location = var.region   # asia-east2 (Hong Kong)
      }
    }
  }

  labels = local.common_labels

  # Description: MySQL database password for Cloud SQL
}

# Add the actual password value (the "letter inside the envelope")
resource "google_secret_manager_secret_version" "db_password" {
  secret = google_secret_manager_secret.db_password.id

  # The actual password — taken from terraform.tfvars (never hardcoded!)
  secret_data = var.db_password

  # Note: Terraform marks this as 'sensitive' automatically because
  # the variable db_password has 'sensitive = true' in variables.tf
}


# ------------------------------------------------------------
# 2. JWT SECRET (For Authentication Tokens)
# ------------------------------------------------------------
# JSON Web Tokens (JWT) are used for user login sessions.
# This secret is used to sign/verify login tokens.
# We generate a random 32-byte key so it's unique per environment.
# ------------------------------------------------------------

# Generate a random 32-byte key (base64 encoded)
resource "random_password" "jwt_secret" {
  length  = 32      # 32 characters
  special = true    # Include special characters for strength
}

# Create the secret container
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "${local.name_prefix}-jwt-secret-${var.environment}"
  # Example: "northpoint-jwt-secret-dev"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = local.common_labels

  # Description: JWT signing key for user authentication tokens
}

# Store the generated key
resource "google_secret_manager_secret_version" "jwt_secret" {
  secret      = google_secret_manager_secret.jwt_secret.id
  secret_data = random_password.jwt_secret.result
}


# ------------------------------------------------------------
# 3. APPLICATION SECRET KEY
# ------------------------------------------------------------
# Used for session encryption, CSRF protection, and other
# application-level security features in the PHP framework.
# ------------------------------------------------------------

resource "random_password" "app_secret" {
  length  = 64       # 64 characters for strong encryption
  special = false    # No special chars (some PHP frameworks don't handle them well)
}

resource "google_secret_manager_secret" "app_secret" {
  secret_id = "${local.name_prefix}-app-secret-${var.environment}"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  labels = local.common_labels

  # Description: Application secret key for session encryption and CSRF
}

resource "google_secret_manager_secret_version" "app_secret" {
  secret      = google_secret_manager_secret.app_secret.id
  secret_data = random_password.app_secret.result
}

