# ============================================================
# monitoring.tf — Cloud Monitoring & Alerting
# ============================================================
# Monitoring answers the question: "Is our store working right now?"
#
# Instead of waiting for the client to phone us, we set up:
#   📊 Dashboards — visual overview of system health
#   🔔 Alerts — automatic notifications when something breaks
#   🏥 Uptime Checks — pings the store every 60 seconds
#
# If the store goes down or gets slow:
#   1. Uptime check fails
#   2. Alert fires
#   3. Email sent to the team
#   4. Team investigates (before the client notices!)
# ============================================================


# ------------------------------------------------------------
# 1. NOTIFICATION CHANNEL (Where Alerts Go)
# ------------------------------------------------------------
# When an alert fires, where should the notification be sent?
# This creates an email notification channel.
# In production, add Slack, PagerDuty, or SMS channels too.
# ------------------------------------------------------------
resource "google_monitoring_notification_channel" "email" {
  count = var.alert_email != "" ? 1 : 0
  # Only create this if an email address was provided

  display_name = "Northpoint DevOps Email (${var.environment})"
  type         = "email"   # Notification type: email

  labels = {
    email_address = var.alert_email   # e.g., "devops@visibleone.com"
  }

  description = "Email notifications for Northpoint Living alerts"
}


# ------------------------------------------------------------
# 2. UPTIME CHECK (Is the Store Alive?)
# ------------------------------------------------------------
# Google sends a health check request to our store every 60 seconds
# from multiple global locations. If the check fails from multiple
# locations, it means the store is genuinely down (not just a
# network blip from one location).
#
# This is how we detect outages FAST — within 60-120 seconds.
# ------------------------------------------------------------
resource "google_monitoring_uptime_check_config" "storefront" {
  display_name = "Northpoint Storefront Health Check (${var.environment})"

  # How often to check (in seconds)
  period = "60s"   # Every 60 seconds

  # How long to wait for a response before considering it "down"
  timeout = "10s"  # 10 second timeout

  # What to check
  monitored_resource {
    type = "cloud_run_revision"
    labels = {
      project_id         = var.project_id
      service_name       = google_cloud_run_v2_service.storefront.name
      location           = var.region
    }
  }

  # HTTP check configuration
  http_check {
    path         = var.uptime_check_path   # "/api/health"
    port         = 443                     # HTTPS
    use_ssl      = true                    # Use HTTPS
    validate_ssl = true                    # Verify SSL certificate is valid

    # Consider these status codes as "healthy"
    accepted_response_status_codes {
      status_value = 200   # HTTP 200 OK
    }
  }

  # Check from these regions (to confirm it's a real outage, not a local issue)
  selected_regions = [
    "ASIA_PACIFIC",   # Check from Asia (close to our users)
    "USA",            # Check from US (different continent)
  ]
}


# ------------------------------------------------------------
# 3. ALERT: High Error Rate
# ------------------------------------------------------------
# If more than 1% of requests return errors (5xx status codes),
# something is wrong with our application. Send an alert.
#
# 5xx errors mean the SERVER is broken, not the user's request.
# Examples: 500 Internal Server Error, 502 Bad Gateway, 503 Unavailable
# ------------------------------------------------------------
resource "google_monitoring_alert_policy" "high_error_rate" {
  count = var.alert_email != "" ? 1 : 0

  display_name = "Northpoint: High Error Rate > 1% (${var.environment})"

  # How to combine conditions (AND = all must be true, OR = any)
  combiner = "OR"

  conditions {
    display_name = "Cloud Run 5xx error rate exceeds 1%"

    condition_threshold {
      filter = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.labels.response_code_class = \"5xx\""

      # Trigger when error count exceeds threshold
      threshold_value = 0.01   # 1% error rate
      comparison      = "COMPARISON_GT"   # Greater than

      # Calculate over a 5-minute window
      duration = "300s"   # 5 minutes

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  # Where to send the alert
  notification_channels = var.alert_email != "" ? [google_monitoring_notification_channel.email[0].id] : []

  # Auto-close the alert after the problem resolves
  alert_strategy {
    auto_close = "1800s"   # Close alert after 30 minutes of no errors
  }

  documentation {
    content   = "## High Error Rate Alert\n\nMore than 1% of requests to the Northpoint storefront are returning 5xx errors.\n\n### Actions:\n1. Check Cloud Run logs: `gcloud logging read 'resource.type=cloud_run_revision'`\n2. Check recent deployments: Was a new version just deployed?\n3. Check Cloud SQL: Is the database healthy?\n4. If a recent deployment caused it: Roll back immediately"
    mime_type = "text/markdown"
  }
}


# ------------------------------------------------------------
# 4. ALERT: Cloud SQL High CPU
# ------------------------------------------------------------
# If the database CPU usage stays above 80% for 5 minutes,
# it may be struggling under load. This is an early warning
# that we might need to scale up or add a read replica.
# ------------------------------------------------------------
resource "google_monitoring_alert_policy" "db_high_cpu" {
  count = var.alert_email != "" ? 1 : 0

  display_name = "Northpoint: Database CPU > 80% (${var.environment})"

  combiner = "OR"

  conditions {
    display_name = "Cloud SQL CPU utilization exceeds 80%"

    condition_threshold {
      filter = "resource.type = \"cloudsql_database\" AND metric.type = \"cloudsql.googleapis.com/database/cpu/utilization\""

      threshold_value = 0.8   # 80% CPU utilization
      comparison      = "COMPARISON_GT"

      duration = "300s"   # Sustained for 5 minutes

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"   # Average over period
      }
    }
  }

  notification_channels = var.alert_email != "" ? [google_monitoring_notification_channel.email[0].id] : []

  alert_strategy {
    auto_close = "3600s"   # Close after 1 hour of normal CPU
  }

  documentation {
    content   = "## Database High CPU Alert\n\nCloud SQL CPU utilization has been above 80% for 5+ minutes.\n\n### Possible Causes:\n- Campaign traffic spike (expected — check if a campaign is running)\n- Slow/unoptimised queries\n- Missing database indexes\n\n### Actions:\n1. Check slow query log: `gcloud sql operations list --instance=northpoint-db`\n2. If campaign spike: Consider adding a read replica\n3. If unexpected: Investigate query patterns in Cloud SQL Insights"
    mime_type = "text/markdown"
  }
}

