# ============================================================
# vpc.tf — Virtual Private Cloud Network
# ============================================================
# A VPC is like a private, isolated network inside Google Cloud.
# Think of it as the "walls" around our infrastructure:
#
#   - The DATABASE sits inside these walls (private, no internet access)
#   - Cloud Run connects through a special "door" (VPC Connector)
#   - The outside world can ONLY reach our app through the Load Balancer
#
# WHY: The database should NEVER be accessible from the internet.
#       This is a fundamental security requirement (PDPO compliance).
# ============================================================


# ------------------------------------------------------------
# 1. THE VPC NETWORK (The Private Network Itself)
# ------------------------------------------------------------
# This creates the top-level network container.
# auto_create_subnetworks = false because we want full control
# over IP ranges (important for security and multi-region expansion).
# ------------------------------------------------------------
resource "google_compute_network" "vpc" {
  name = "${local.name_prefix}-vpc-${var.environment}"
  # Example name: "northpoint-vpc-dev"

  # Don't auto-create subnets in every region — we only need Hong Kong
  auto_create_subnetworks = false

  # Use the latest network routing mode
  routing_mode = "REGIONAL"

  description = "Private VPC network for Northpoint Living e-commerce platform"
}


# ------------------------------------------------------------
# 2. SUBNET (IP Address Range in Hong Kong)
# ------------------------------------------------------------
# A subnet defines the IP address range available in a specific region.
# Our app and database will use IPs from this range.
# 10.0.0.0/24 = 256 IP addresses (more than enough for our needs).
# ------------------------------------------------------------
resource "google_compute_subnetwork" "main" {
  name = "${local.name_prefix}-subnet-${var.environment}"
  # Example name: "northpoint-subnet-dev"

  region  = var.region          # asia-east2 (Hong Kong)
  network = google_compute_network.vpc.id

  # IP range: 10.0.0.0 to 10.0.0.255 (256 addresses)
  ip_cidr_range = "10.0.0.0/24"

  # Enable private Google API access — lets resources in this subnet
  # reach Google APIs (Cloud Storage, Secret Manager, etc.) without
  # going through the public internet.
  private_ip_google_access = true

  description = "Main subnet in Hong Kong for Northpoint Living"
}


# ------------------------------------------------------------
# 3. PRIVATE SERVICE ACCESS (For Cloud SQL)
# ------------------------------------------------------------
# Cloud SQL needs a range of private IPs to use.
# This "reserves" a block of IPs specifically for managed services
# like Cloud SQL, so they get private addresses inside our VPC.
#
# Without this, Cloud SQL would need a public IP (security risk!).
# ------------------------------------------------------------

# Reserve an IP range for Google managed services
resource "google_compute_global_address" "private_ip_range" {
  name = "${local.name_prefix}-private-ip-${var.environment}"
  # Example name: "northpoint-private-ip-dev"

  purpose       = "VPC_PEERING"                    # Reserved for Google services
  address_type  = "INTERNAL"                       # Private IP (not public)
  prefix_length = 20                               # /20 = 4096 IP addresses (enough for Cloud SQL + future services)
  network       = google_compute_network.vpc.id

  description = "Reserved IP range for Cloud SQL and other Google managed services"
}

# Create the peering connection between our VPC and Google's services network
resource "google_service_networking_connection" "private_vpc_connection" {
  network = google_compute_network.vpc.id

  service = "servicenetworking.googleapis.com"   # Google's managed services

  # Use our reserved IP range
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  # Allow this connection to be deleted when we run 'terraform destroy'
  deletion_policy = "ABANDON"
}


# ------------------------------------------------------------
# 4. SERVERLESS VPC CONNECTOR (The "Door" for Cloud Run)
# ------------------------------------------------------------
# Cloud Run runs OUTSIDE your VPC by default (it's serverless).
# This connector creates a "door" that lets Cloud Run reach
# resources INSIDE the VPC (specifically, our Cloud SQL database).
#
# Without this, Cloud Run cannot talk to Cloud SQL's private IP.
#
# Think of it as:
#   Cloud Run → [VPC Connector door] → VPC → Cloud SQL
# ------------------------------------------------------------
resource "google_vpc_access_connector" "connector" {
  name = "${local.name_prefix}-connector-${var.environment}"
  # Example name: "northpoint-connector-dev"

  region = var.region   # asia-east2 (Hong Kong)

  # IP range for the connector itself (must not overlap with other ranges)
  ip_cidr_range = "10.8.0.0/28"   # Small range: 16 IPs (enough for the connector)

  # Which VPC to connect to
  network = google_compute_network.vpc.id

  # Machine type for the connector VMs (these are tiny helper VMs that route traffic)
  # e2-micro = cheapest option, sufficient for our traffic levels
  machine_type = "e2-micro"

  # Minimum and maximum instances for the connector
  min_instances = 2    # At least 2 for reliability
  max_instances = 3    # Cap at 3 to control cost

  # Description: Connects Cloud Run to VPC for private Cloud SQL access
}


# ------------------------------------------------------------
# 5. FIREWALL RULES
# ------------------------------------------------------------
# Firewalls control what traffic can enter/leave the VPC.
# These rules ensure:
#   - Only internal traffic can reach the database
#   - Health checks from Google's load balancer are allowed
#   - All other inbound traffic is blocked
# ------------------------------------------------------------

# Allow internal communication within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal-${var.environment}"
  network = google_compute_network.vpc.id

  # Allow all traffic from within the VPC
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]   # All TCP ports
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]   # All UDP ports
  }
  allow {
    protocol = "icmp"   # Ping (useful for debugging)
  }

  # Only from our internal IP ranges
  source_ranges = [
    "10.0.0.0/24",    # Main subnet
    "10.8.0.0/28",    # VPC connector
  ]

  description = "Allow all internal VPC traffic"
}

# Allow Google health check probes
# (The load balancer sends these to verify Cloud Run is healthy)
resource "google_compute_firewall" "allow_health_checks" {
  name    = "${local.name_prefix}-allow-health-checks-${var.environment}"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]   # HTTP, HTTPS, and our app port
  }

  # These are Google's health check IP ranges (official, documented)
  # https://cloud.google.com/load-balancing/docs/health-check-concepts#ip-ranges
  source_ranges = [
    "130.211.0.0/22",   # Google health checker IPs
    "35.191.0.0/16",    # Google health checker IPs
  ]

  description = "Allow Google Cloud health check probes for load balancer"
}

