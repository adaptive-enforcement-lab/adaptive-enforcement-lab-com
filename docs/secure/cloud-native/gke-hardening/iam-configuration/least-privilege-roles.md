---
title: Least Privilege Roles
description: Define fine-grained IAM roles for GKE service accounts with minimal permissions for nodes, cluster admins, and developer access using Terraform best practices.
---

# Least Privilege Roles

GKE clusters require specific IAM roles. Grant only the minimum roles needed.

## Service Account Roles

```hcl
# gke/iam/roles.tf
locals {
  # Minimal roles for node service account
  node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ]

  # Minimal roles for cluster operations
  cluster_admin_roles = [
    "roles/container.admin",
  ]

  # Minimal roles for developers (read-only)
  developer_roles = [
    "roles/container.developer",
  ]
}

# Grant roles to node service account
resource "google_project_iam_member" "node_role" {
  for_each = toset(local.node_roles)

  project = var.gcp_project
  role    = each.value
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# Cluster admin service account
resource "google_service_account" "cluster_admin" {
  account_id   = "cluster-admin"
  display_name = "Cluster admin service account"
}

resource "google_project_iam_member" "cluster_admin" {
  project = var.gcp_project
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.cluster_admin.email}"
}

# Developer service account
resource "google_service_account" "developer" {
  account_id   = "developer"
  display_name = "Developer read-only access"
}

resource "google_project_iam_member" "developer" {
  project = var.gcp_project
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.developer.email}"
}

output "node_service_account" {
  value       = google_service_account.nodes.email
  description = "Node service account email"
}

output "cluster_admin_service_account" {
  value       = google_service_account.cluster_admin.email
  description = "Cluster admin service account email"
}

output "developer_service_account" {
  value       = google_service_account.developer.email
  description = "Developer service account email"
}
```

!!! warning "Avoid Broad Permissions"

    Never grant `Editor` or `Owner` roles to service accounts. Use fine-grained predefined or custom roles.

## Role Descriptions

| Role | Purpose | Risk |
|------|---------|------|
| `roles/container.admin` | Full cluster management | High - Unrestricted access |
| `roles/container.developer` | Deploy and manage workloads | Medium - Read pods, logs, exec |
| `roles/container.viewer` | Read-only cluster access | Low - Observability only |
| `roles/logging.logWriter` | Write logs to Cloud Logging | Low - Nodes only |
| `roles/monitoring.metricWriter` | Write metrics to Cloud Monitoring | Low - Nodes only |

## IAM Security Checklist

```bash
#!/bin/bash
# IAM configuration verification

echo "=== Service Accounts ==="
gcloud iam service-accounts list \
  --format="table(email,displayName)" \
  --filter="email~gke|email~cluster"

echo ""
echo "=== IAM Bindings ==="
for sa in $(gcloud iam service-accounts list --format="value(email)" --filter="email~gke"); do
  echo "Service Account: $sa"
  gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$sa" \
    --format="table(bindings.role)"
  echo ""
done
```

## Related Content

- **[Workload Identity Federation](workload-identity-federation.md)** - External identity integration
- **[Audit Logging](audit-logging.md)** - Comprehensive activity tracking
- **[Cluster Configuration](../cluster-configuration/index.md)** - Private GKE cluster setup
