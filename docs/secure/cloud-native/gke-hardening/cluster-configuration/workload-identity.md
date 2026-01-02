---
title: Workload Identity
description: Configure Workload Identity for secure pod-to-GCP authentication without service account keys, linking Kubernetes SAs to GCP SAs with Terraform best practices.
---

# Workload Identity

Workload Identity enables pod-to-GCP authentication without managing service account keys. Pods assume a Kubernetes service account linked to a GCP service account.

!!! danger "Avoid Metadata Server"

    Using VM metadata server for pod authentication is insecure. Workload Identity eliminates this attack vector.

## Terraform Configuration

```hcl
# gke/workload-identity/main.tf
# Kubernetes provider
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  token                  = var.cluster_token
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}

# Example: Kubernetes service account for an application
resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

resource "kubernetes_service_account" "app_sa" {
  metadata {
    namespace = kubernetes_namespace.apps.metadata[0].name
    name      = "my-app-ksa"

    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.app_gsa.email
    }
  }
}

# GCP service account for the application
resource "google_service_account" "app_gsa" {
  account_id   = "my-app-gsa"
  display_name = "Service account for my-app"
}

# Bind Kubernetes SA to GCP SA
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.app_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.gcp_project}.svc.id.goog[apps/my-app-ksa]"
}

# Grant application-specific permissions
resource "google_project_iam_member" "app_permissions" {
  project = var.gcp_project
  role    = "roles/storage.objectViewer"  # Example: read-only to Cloud Storage
  member  = "serviceAccount:${google_service_account.app_gsa.email}"
}

# Pod manifest using Workload Identity
resource "kubernetes_deployment" "my_app" {
  metadata {
    namespace = kubernetes_namespace.apps.metadata[0].name
    name      = "my-app"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "my-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "my-app"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.app_sa.metadata[0].name

        container {
          name  = "my-app"
          image = "gcr.io/my-project/my-app:latest"

          env {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = "/var/run/secrets/workload-identity/key.json"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }
    }
  }
}

output "app_service_account" {
  value       = google_service_account.app_gsa.email
  description = "GCP service account used by application"
}
```

## Verification

```bash
# Verify Workload Identity binding
kubectl get serviceaccount my-app-ksa -n apps -o jsonpath='{.metadata.annotations}'

# Test pod can authenticate to GCP
kubectl run -it --image=google/cloud-sdk:slim test-wi \
  --serviceaccount=my-app-ksa \
  -n apps \
  -- gcloud auth list
```

## Related Content

- **[Private Cluster](private-cluster.md)** - Private GKE cluster setup
- **[Binary Authorization](binary-authorization.md)** - Image verification
- **[IAM Configuration](../iam-configuration/index.md)** - Least-privilege access control
- **[Workload Identity Implementation](../../workload-identity/index.md)** - Detailed Workload Identity guide
