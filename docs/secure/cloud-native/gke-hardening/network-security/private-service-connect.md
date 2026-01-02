---
title: Private Service Connect
description: Configure Private Service Connect endpoints for secure, private connectivity to GCP services without public IPs using Terraform forwarding rules and DNS zones.
---

# Private Service Connect

Route traffic through Private Service Connect endpoints for secure, private connectivity to GCP services.

!!! abstract "Private Service Connect Benefits"

    - No public IP addresses required
    - Traffic stays on Google's backbone
    - Simplified security policy management
    - Supports cross-project access

## Terraform Configuration

```hcl
# gke/networking/psc.tf
# Forwarding rule for Private Service Connect
resource "google_compute_forwarding_rule" "psc_endpoint" {
  name                = "my-psc-endpoint"
  region              = var.region
  load_balancing_scheme = "INTERNAL"
  target              = google_compute_service_attachment.psc_service.id
  network             = google_compute_network.primary.id
  subnetwork          = google_compute_subnetwork.primary.id
  ip_protocol         = "TCP"
  allow_global_access = false

  # Static internal IP for consistency
  ip_address = "10.0.0.50"
}

# Service attachment for Private Service Connect
resource "google_compute_service_attachment" "psc_service" {
  name                = "my-psc-service"
  region              = var.region
  target_service      = google_compute_network_endpoint_group.psc_neg.id
  enable_proxy_protocol = false

  nat_subnets = [google_compute_subnetwork.primary.id]

  consumer_accept_lists {
    project_id_or_num = var.gcp_project
  }
}

# Network Endpoint Group for PSC
resource "google_compute_network_endpoint_group" "psc_neg" {
  name           = "my-psc-neg"
  network        = google_compute_network.primary.id
  subnetwork     = google_compute_subnetwork.primary.id
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port   = 443
}

# DNS record pointing to PSC endpoint
resource "google_dns_record_set" "psc_dns" {
  name       = "api.internal."
  type       = "A"
  ttl        = 300
  managed_zone = google_dns_managed_zone.internal.name
  rrdatas    = ["10.0.0.50"]
}

resource "google_dns_managed_zone" "internal" {
  name       = "internal"
  dns_name   = "internal."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.primary.id
    }
  }
}
```

## Verification

```bash
# Check PSC endpoint
gcloud compute forwarding-rules describe my-psc-endpoint \
  --region us-central1 \
  --format="value(IPAddress)"

# Test connectivity from pod
kubectl run -it --image=curlimages/curl test-psc \
  -- curl -I https://api.internal/
```

!!! tip "DNS Configuration"

    Use Cloud DNS private zones to route service traffic through PSC endpoints automatically.

## Related Content

- **[VPC-Native Networking](vpc-native.md)** - Container-native IP allocation
- **[Network Policies](network-policies.md)** - Pod-to-pod traffic control
- **[Cloud Armor](cloud-armor.md)** - DDoS protection and WAF

## References

- [Private Service Connect](https://cloud.google.com/vpc/docs/private-service-connect)
