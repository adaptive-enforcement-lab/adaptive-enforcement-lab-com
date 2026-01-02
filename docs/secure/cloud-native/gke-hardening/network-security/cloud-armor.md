---
title: Cloud Armor
description: Configure Cloud Armor for DDoS mitigation, WAF protection, rate limiting, geo-blocking, and bot defense at the GKE ingress layer with Terraform automation.
---

# Cloud Armor

Cloud Armor provides DDoS protection and WAF capabilities at the network edge.

!!! warning "Layer 7 Protection"

    Cloud Armor operates at the HTTP layer. Configure it on your Load Balancer backends.

## Terraform Configuration

```hcl
# gke/security/cloud-armor.tf
resource "google_compute_security_policy" "policy" {
  name = "gke-cloud-armor"

  # Default rule (deny all)
  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default deny rule"
  }

  # Allow from specific countries
  rule {
    action   = "allow"
    priority = "100"
    match {
      expr {
        expression = "origin.region_code in ['US', 'CA', 'GB', 'DE']"
      }
    }
    description = "Allow from approved countries"
  }

  # Rate limit
  rule {
    action   = "rate_based_ban"
    priority = "200"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"

      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }

      ban_duration_sec = 600
    }
    description = "Rate limit suspicious requests"
  }

  # Block known malicious patterns
  rule {
    action   = "deny(403)"
    priority = "300"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable') || evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "Block XSS and SQLi attacks"
  }
}

# Attach to Ingress (requires load balancer backend)
output "cloud_armor_policy" {
  value       = google_compute_security_policy.policy.id
  description = "Cloud Armor security policy ID"
}
```

!!! note "Preconfigured Rules"

    Cloud Armor includes preconfigured rules for common attacks (XSS, SQLi, LFI, RCE). Use `evaluatePreconfiguredExpr()` to enable them.

## Deployment

```bash
# Apply Cloud Armor policy
terraform -chdir=gke/security apply

# Verify policy
gcloud compute security-policies describe gke-cloud-armor

# Test rate limiting
for i in {1..150}; do
  curl https://my-app.example.com/
done
# After 100 requests in 60s, you should receive 429 responses
```

## Network Security Checklist

```bash
#!/bin/bash
# Cloud Armor verification

echo "=== Cloud Armor ==="
gcloud compute security-policies list --format="value(name)" | \
  wc -l | awk '{if ($1 > 0) print "✓ Cloud Armor enabled"; else print "✗ No Cloud Armor policies"}'
```

## Related Content

- **[VPC-Native Networking](vpc-native.md)** - Container-native IP allocation
- **[Network Policies](network-policies.md)** - Pod-to-pod traffic control
- **[Private Service Connect](private-service-connect.md)** - Secure GCP service access

## References

- [Cloud Armor](https://cloud.google.com/armor/docs)
- [Cloud Armor Rules Language](https://cloud.google.com/armor/docs/rules-language-reference)
