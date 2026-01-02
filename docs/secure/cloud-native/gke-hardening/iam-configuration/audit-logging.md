---
title: Audit Logging
description: Enable comprehensive Cloud Logging audit trails for GKE cluster management with Cloud Storage sinks, lifecycle policies, and compliance retention controls.
---

# Audit Logging

Enable comprehensive audit logging for cluster management and API access.

!!! danger "Compliance Requirement"

    Audit logging is mandatory for most compliance frameworks (SOC 2, ISO 27001, PCI DSS). Configure before production deployment.

## Terraform Configuration

```hcl
# gke/logging/audit.tf
# Cloud Logging sink for GKE audit logs
resource "google_logging_project_sink" "gke_audit" {
  name        = "gke-audit-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.audit_logs.name}"
  filter      = <<-EOT
    resource.type = "k8s_cluster"
    AND (
      protoPayload.methodName =~ "create|update|delete|patch"
      OR severity = "ERROR"
    )
  EOT

  unique_writer_identity = true
}

# Grant logging sink permission to write to bucket
resource "google_storage_bucket_iam_member" "audit_logs_writer" {
  bucket = google_storage_bucket.audit_logs.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.gke_audit.writer_identity
}

# Storage bucket for audit logs
resource "google_storage_bucket" "audit_logs" {
  name          = "${var.gcp_project}-gke-audit-logs"
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 30
    }
  }

  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      age = 90
    }
  }

  lifecycle_rule {
    action {
      type          = "Delete"
    }
    condition {
      age = 365
    }
  }
}

output "audit_logs_bucket" {
  value       = google_storage_bucket.audit_logs.name
  description = "Cloud Storage bucket for audit logs"
}
```

!!! note "Retention Policy"

    Logs are retained for 1 year with automatic tiering to cold storage. Adjust based on your compliance requirements.

## Verification

```bash
# Check audit logs in Cloud Logging
gcloud logging read "resource.type=k8s_cluster AND protoPayload.methodName=~'create|delete'" \
  --limit 10 \
  --format=json

# Export logs to analysis
gcloud logging read "resource.type=k8s_cluster" \
  --limit 100 \
  --format=csv > audit_export.csv
```

## Audit Logging Checklist

```bash
#!/bin/bash
# Audit logging verification

echo "=== Audit Logging ==="
gcloud logging sinks list \
  --filter="name~audit" \
  --format="table(name,destination,filter)"
```

## Related Content

- **[Least Privilege Roles](least-privilege-roles.md)** - Fine-grained IAM permissions
- **[Workload Identity Federation](workload-identity-federation.md)** - External identity integration
- **[Cluster Configuration](../cluster-configuration/index.md)** - Private GKE cluster setup

## References

- [Cloud Audit Logs](https://cloud.google.com/logging/docs/audit)
- [GKE Audit Logging](https://cloud.google.com/kubernetes-engine/docs/how-to/audit-logging)
