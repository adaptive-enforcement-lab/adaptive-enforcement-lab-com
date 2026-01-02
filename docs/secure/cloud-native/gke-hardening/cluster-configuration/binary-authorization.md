---
title: Binary Authorization
description: Enforce binary authorization policies with Shielded GKE nodes, secure boot, measured boot, image attestation, and container signature verification workflows.
---

# Binary Authorization

Shielded GKE nodes provide secure boot, measured boot, and integrity monitoring. Binary Authorization ensures only verified container images run on the cluster.

!!! tip "Image Verification"

    Binary Authorization integrates with Artifact Registry and Container Analysis for automated vulnerability scanning and policy enforcement.

## Terraform Configuration

```hcl
# gke/security/binary-auth.tf
resource "google_binary_authorization_policy" "policy" {
  admission_whitelist_patterns {
    name_pattern = "gcr.io/my-project/*"
  }

  admission_whitelist_patterns {
    name_pattern = "docker.io/library/*"
  }

  default_admission_rule {
    require_attestations_by = [google_binary_authorization_attestor.prod.name]
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
  }

  global_policy_evaluation_enabled = true
  enable_policy_dry_run            = true

  kubernetes_namespace_admissions {
    name            = "prod-*"
    require_attestations_by = [google_binary_authorization_attestor.prod.name]
  }

  kubernetes_namespace_admissions {
    name            = "dev"
    require_attestations_by = []
  }
}

resource "google_binary_authorization_attestor" "prod" {
  name = "prod-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor_note.name

    public_keys {
      id = "prod-key-v1"

      pgp_public_key {
        public_key_pem = file("${path.module}/keys/attestor-public.pgp")
      }
    }
  }
}

resource "google_container_analysis_note" "attestor_note" {
  name = "prod-attestor-note"

  related_url {
    url = "https://example.com/attestation"
  }
}

output "binary_authorization_policy" {
  value       = google_binary_authorization_policy.policy.name
  description = "Binary Authorization policy name"
}
```

## Related Content

- **[Private Cluster](private-cluster.md)** - Private GKE cluster setup
- **[Workload Identity](workload-identity.md)** - Pod-to-GCP authentication
- **[Runtime Security](../runtime-security/index.md)** - Pod security and admission control
