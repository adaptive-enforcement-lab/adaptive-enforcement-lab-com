---
title: Private Cluster Advanced Configuration
description: Configure Cloud KMS encryption for etcd database, implement Binary Authorization policies, enable private endpoints, and deploy Cloud Armor WAF protection.
---

# Private Cluster Advanced Configuration

Advanced security features including etcd encryption with Cloud KMS, binary authorization, and enhanced monitoring.

!!! warning "etcd Contains All Secrets"
    Unencrypted etcd stores Kubernetes secrets in plaintext. Enable Cloud KMS encryption before deploying production workloads.

## Database Encryption with Cloud KMS

Encrypt Kubernetes secrets at rest using Cloud KMS keys with automatic rotation.

```hcl
# KMS key for cluster encryption
resource "google_kms_key_ring" "cluster" {
  name     = "${var.cluster_name}-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "cluster_key" {
  name            = "${var.cluster_name}-key"
  key_ring        = google_kms_key_ring.cluster.id
  rotation_period = "7776000s" # 90 days
}

# Update cluster to use KMS encryption
resource "google_container_cluster" "primary" {
  # ... basic config from private-cluster-setup.md

  # Database encryption
  database_encryption {
    state    = "ENCRYPTED"
    key_name = google_kms_crypto_key.cluster_key.id
  }
}
```

### Grant KMS Permissions

```hcl
# Grant GKE service account permission to use KMS key
data "google_project" "current" {}

resource "google_kms_crypto_key_iam_member" "cluster_key_user" {
  crypto_key_id = google_kms_crypto_key.cluster_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}
```

## Binary Authorization

Require all images to be signed and verified before deployment.

```hcl
# Enable Binary Authorization
resource "google_container_cluster" "primary" {
  # ... other config

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }
}

# Create Binary Authorization policy
resource "google_binary_authorization_policy" "policy" {
  admission_whitelist_patterns {
    name_pattern = "gcr.io/${var.gcp_project}/*"
  }

  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.attestor.name
    ]
  }

  global_policy_evaluation_mode = "ENABLE"
}

# Create attestor for image signing
resource "google_binary_authorization_attestor" "attestor" {
  name = "${var.cluster_name}-attestor"
  attestation_authority_note {
    note_reference = google_container_analysis_note.note.name
  }
}

resource "google_container_analysis_note" "note" {
  name = "${var.cluster_name}-attestor-note"
  attestation_authority {
    hint {
      human_readable_name = "Image attestor for ${var.cluster_name}"
    }
  }
}
```

## Private Endpoint Access

Configure private endpoint for API server access from on-premises or VPN.

```hcl
resource "google_container_cluster" "primary" {
  # ... other config

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Allow access from Cloud Shell and authorized networks
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr_block
      display_name = "Admin network"
    }
    cidr_blocks {
      cidr_block   = var.vpn_cidr_block
      display_name = "VPN network"
    }
  }
}
```

## Cloud Armor for GKE Ingress

Protect ingress traffic with Cloud Armor DDoS protection and WAF rules.

```hcl
# Cloud Armor security policy
resource "google_compute_security_policy" "policy" {
  name = "${var.cluster_name}-security-policy"

  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["9.9.9.0/24"] # Blocked IP ranges
      }
    }
    description = "Block known malicious IPs"
  }

  rule {
    action   = "rate_based_ban"
    priority = "2000"
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
    description = "Rate limit requests"
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }
}

# Attach to backend service via ingress annotation
# In Kubernetes manifest:
# metadata:
#   annotations:
#     cloud.google.com/backend-config: '{"default": "security-policy"}'
```

## Security Monitoring

Enable GKE security features and log analysis.

```hcl
resource "google_container_cluster" "primary" {
  # ... other config

  # Security monitoring
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
    managed_prometheus {
      enabled = true
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # GKE Security Posture
  security_posture_config {
    mode               = "BASIC"
    vulnerability_mode = "VULNERABILITY_BASIC"
  }

  # Workload vulnerability scanning
  workload_vulnerability_scanning {
    enabled = true
  }
}
```

## Validation

```bash
# Verify KMS encryption
gcloud container clusters describe prod-cluster \
  --region us-central1 \
  --format="value(databaseEncryption.keyName)"

# Check Binary Authorization is enabled
gcloud container clusters describe prod-cluster \
  --region us-central1 \
  --format="value(binaryAuthorization.evaluationMode)"

# Test image signing requirement
kubectl run test --image=nginx:latest
# Should fail with: "image policy webhook backend denied"

# Verify private endpoint
gcloud container clusters describe prod-cluster \
  --region us-central1 \
  --format="value(privateClusterConfig.enablePrivateEndpoint)"
```

## Related Content

- **[Private Cluster Setup →](private-cluster-setup.md)** - Basic cluster configuration
- **[Workload Identity](../../workload-identity/index.md)** - Pod-to-GCP authentication
- **[Binary Authorization](binary-authorization.md)** - Image verification
- **[Network Security](../network-security/index.md)** - VPC networking and policies
