# ============================================================
# storage.tf — Cloud Storage (Product Media Files)
# ============================================================
# Cloud Storage is Google's object storage service — like a
# massive, infinitely scalable hard drive in the cloud.
#
# We use it to store:
#   📸 Product images (the 180GB of product media)
#   📦 Database backup exports (cross-region safety net)
#
# WHY Cloud Storage instead of a regular disk?
#   ✅ Unlimited size — never runs out of space
#   ✅ 99.999999999% durability (11 nines — Google guarantees your files won't be lost)
#   ✅ Served through CDN — fast downloads worldwide
#   ✅ Much cheaper than SSD disk storage
#   ✅ No server needed — just upload files via API
# ============================================================


# ------------------------------------------------------------
# 1. PRODUCT MEDIA BUCKET (Product Images)
# ------------------------------------------------------------
# This bucket stores all product photos, thumbnails, and media.
# Currently ~180GB, will grow as new products are added.
#
# Files are served to customers through Cloud CDN for speed.
# Example URL: https://storage.googleapis.com/northpoint-media-a1b2/products/chair-001.jpg
# ------------------------------------------------------------
resource "google_storage_bucket" "product_media" {
  name = "${local.name_prefix}-media-${local.suffix}"
  # Example: "northpoint-media-a1b2"
  # Note: Bucket names must be GLOBALLY unique across ALL GCP users,
  # which is why we add the random suffix.

  # Location: Hong Kong (PDPO data residency — media stays in HK)
  location = var.storage_location   # "ASIA-EAST2"

  # Storage class: STANDARD for frequently accessed files
  storage_class = var.storage_class   # "STANDARD"

  # Access control: Uniform (simpler, recommended by Google)
  # All objects in the bucket share the same access policy
  uniform_bucket_level_access = true

  # ---- LIFECYCLE RULES ----
  # Automatically manage old files to save costs

  # Rule 1: Move files not accessed for 90 days to cheaper storage
  lifecycle_rule {
    condition {
      age = 90   # Days since last access
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"   # Cheaper but small access fee
    }
  }

  # Rule 2: Delete temporary upload files after 1 day
  lifecycle_rule {
    condition {
      age                = 1       # 1 day old
      matches_prefix     = ["tmp/"]   # Only files in tmp/ folder
    }
    action {
      type = "Delete"
    }
  }

  # ---- VERSIONING ----
  # Keep previous versions of files when they're overwritten.
  # Useful if someone accidentally uploads the wrong product image.
  versioning {
    enabled = true
  }

  # ---- CORS (Cross-Origin Resource Sharing) ----
  # Allows the storefront website to directly load images from this bucket.
  # Without CORS, browsers would block image requests as a security measure.
  cors {
    origin          = ["*"]   # Allow from any domain (restrict in production)
    method          = ["GET", "HEAD"]   # Only allow reading, not uploading from browser
    response_header = ["Content-Type", "Content-Length", "Cache-Control"]
    max_age_seconds = 3600    # Cache CORS response for 1 hour
  }

  # Allow terraform destroy to delete the bucket even if it has files
  force_destroy = true   # Set to false in production!

  labels = local.common_labels
}


# ------------------------------------------------------------
# 2. DATABASE BACKUP BUCKET (Cross-Region Safety)
# ------------------------------------------------------------
# Daily database exports are stored here as an extra safety layer.
# This bucket is in SINGAPORE (asia-southeast1) — a different
# region from our database (Hong Kong).
#
# WHY a different region?
#   If Hong Kong data centre has a major disaster (earthquake,
#   power grid failure), our backups survive in Singapore.
#   This is our "Layer 3" backup from the submission.
# ------------------------------------------------------------
resource "google_storage_bucket" "db_backups" {
  name = "${local.name_prefix}-db-backups-${local.suffix}"
  # Example: "northpoint-db-backups-a1b2"

  # Location: SINGAPORE (different region for disaster recovery!)
  location = "ASIA-SOUTHEAST1"

  # NEARLINE: cheaper storage, small access fee
  # We rarely need to access backups (only in emergencies)
  storage_class = "NEARLINE"

  uniform_bucket_level_access = true

  # ---- LIFECYCLE: Auto-delete old backups ----
  # Keep backups for 30 days, then automatically delete
  lifecycle_rule {
    condition {
      age = 30   # Delete backups older than 30 days
    }
    action {
      type = "Delete"
    }
  }

  # No versioning needed for backups (each export is unique)
  versioning {
    enabled = false
  }

  force_destroy = true   # Set to false in production!

  labels = local.common_labels
}


# ------------------------------------------------------------
# 3. MAKE PRODUCT MEDIA PUBLICLY READABLE
# ------------------------------------------------------------
# Product images need to be viewable by everyone (customers).
# This IAM binding makes all objects in the media bucket readable
# by anyone on the internet — which is what we want for a store.
#
# Note: Only the media bucket is public. The backup bucket is PRIVATE.
# ------------------------------------------------------------
resource "google_storage_bucket_iam_member" "media_public_read" {
  bucket = google_storage_bucket.product_media.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"   # ← Public access (anyone can view images)
}

