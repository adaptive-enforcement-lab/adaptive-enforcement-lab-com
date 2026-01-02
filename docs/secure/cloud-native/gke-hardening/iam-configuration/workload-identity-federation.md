---
title: Workload Identity Federation
description: Enable GitHub Actions OIDC authentication to GCP using Workload Identity Federation, eliminating service account keys with Terraform configuration patterns.
---

# Workload Identity Federation

Workload Identity Federation enables pods to authenticate to external identity providers (e.g., GitHub, external STS servers).

!!! abstract "Use Case"

    Enable GitHub Actions to authenticate to GCP without storing credentials. Each GitHub workflow assumes a GCP service account via OIDC.

## Terraform Configuration

```hcl
# gke/iam/wif.tf
# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  location                  = "global"
  display_name              = "GitHub Workload Identity Pool"
  description               = "Identity pool for GitHub Actions"

  disabled = false
}

# Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  location                           = "global"
  display_name                       = "GitHub Provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Service account for GitHub Actions
resource "google_service_account" "github_actions" {
  account_id   = "github-actions"
  display_name = "GitHub Actions CI/CD"
}

# Allow GitHub to impersonate the service account
resource "google_service_account_iam_member" "github_actions_wif" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/projects/${var.project_number}/locations/global/workloadIdentityPools/${google_iam_workload_identity_pool.github.workload_identity_pool_id}/attribute.repository/my-org/my-repo"
}

# Grant deployment permissions to GitHub Actions
resource "google_project_iam_member" "github_actions_container_developer" {
  project = var.gcp_project
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

resource "google_project_iam_member" "github_actions_artifact_registry" {
  project = var.gcp_project
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}

output "workload_identity_pool" {
  value       = google_iam_workload_identity_pool.github.name
  description = "Workload Identity Pool resource name"
}

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Workload Identity Provider resource name"
}

output "github_actions_service_account" {
  value       = google_service_account.github_actions.email
  description = "Service account for GitHub Actions"
}
```

!!! tip "Repository Filtering"

    Use attribute conditions to limit which GitHub repositories can assume the service account. Replace `my-org/my-repo` with your repository path.

## GitHub Actions Integration

```yaml
# .github/workflows/deploy.yml
name: Deploy to GKE
on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read

    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v1
        with:
          workload_identity_provider: "projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider"
          service_account: "github-actions@my-project.iam.gserviceaccount.com"
          token_format: access_token
          access_token_lifetime: "600s"

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v1

      - name: Deploy to GKE
        run: |
          gcloud container clusters get-credentials prod-cluster \
            --region us-central1 \
            --project ${{ vars.GCP_PROJECT }}
          kubectl apply -f manifests/
```

## Related Content

- **[Least Privilege Roles](least-privilege-roles.md)** - Fine-grained IAM permissions
- **[Audit Logging](audit-logging.md)** - Comprehensive activity tracking
- **[Cluster Configuration](../cluster-configuration/workload-identity.md)** - Workload Identity for pods
