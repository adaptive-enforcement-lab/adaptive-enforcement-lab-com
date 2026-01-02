---
title: Private GKE Cluster Setup
description: Deploy private GKE clusters with VPC-native networking, custom hardened node pools, Workload Identity, and Shielded GKE nodes using Terraform best practices.
---

# Private GKE Cluster Setup

Private clusters prevent unauthenticated access to the Kubernetes API server. All traffic is routed through a Private Service Connect endpoint or Cloud NAT.

!!! warning "Public Cluster Risk"

    Public control planes expose your cluster API to the internet. Even with strong authentication, this increases attack surface and is not recommended for production.

## Terraform Configuration

```hcl
# VPC network for cluster
resource "google_compute_network" "primary" {
  name                    = "${var.cluster_name}-network"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet with secondary ranges for pods and services
resource "google_compute_subnetwork" "primary" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.primary.id
  region        = var.region

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private GKE cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # Remove default node pool (we'll create custom one)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = google_compute_network.primary.id
  subnetwork = google_compute_subnetwork.primary.id

  # Cluster configuration
  min_master_version = var.kubernetes_version

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.gcp_project}.svc.id.goog"
  }

  # Network policy
  enable_network_policy = true

  # Cluster autoscaling
  cluster_autoscaling {
    enabled = true

    resource_limits {
      resource_type = "cpu"
      minimum       = 1
      maximum       = 10
    }

    resource_limits {
      resource_type = "memory"
      minimum       = 10
      maximum       = 100
    }
  }

  # Maintenance windows
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Master authorized networks (restrict API access)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.admin_cidr_block
      display_name = "Admin network"
    }
  }

  # Resource labels for compliance
  resource_labels = {
    environment = var.environment
    team        = var.team
    cost-center = var.cost_center
  }
}

# Custom node pool with hardening
resource "google_container_node_pool" "primary_nodes" {
  name           = "${var.cluster_name}-node-pool"
  location       = var.region
  cluster        = google_container_cluster.primary.name
  initial_node_count = var.initial_node_count

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  node_config {
    # Use custom service account with minimal permissions
    service_account = google_service_account.nodes.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Machine type and disk sizing
    machine_type = var.machine_type
    disk_size_gb = 100
    disk_type    = "pd-ssd"

    # Shielded GKE nodes (secure boot, measured boot, integrity monitoring)
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Metadata server concealment (prevent Pod metadata server access)
    metadata {
      google-compute-enable-display-coip = false
    }

    # Node taints for workload isolation
    taint {
      key    = "workload-type"
      value  = "general"
      effect = "NO_SCHEDULE"
    }

    # Node labels
    labels = {
      environment = var.environment
      workload    = "general"
    }

    # Tags for firewall rules
    tags = [
      "${var.cluster_name}-node",
      "gke-node"
    ]

    # Kubelet configuration for hardening
    kubelet_config {
      cpu_manager_policy = "static"
      cpu_cfs_quota      = true
      cpu_cfs_quota_period = "100ms"
    }
  }

  node_locations = var.availability_zones
}

# Service account for nodes
resource "google_service_account" "nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
}

# Grant minimal IAM permissions to nodes
resource "google_project_iam_member" "nodes_logging" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_project_iam_member" "nodes_monitoring" {
  project = var.gcp_project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_project_iam_member" "nodes_monitoring_viewer" {
  project = var.gcp_project
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}

# Outputs
output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE cluster name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE cluster endpoint"
  sensitive   = true
}

output "region" {
  value       = var.region
  description = "Region where cluster is deployed"
}

output "network_name" {
  value       = google_compute_network.primary.name
  description = "VPC network name"
}
```

## Variables

```hcl
# gke/cluster/variables.tf
variable "gcp_project" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "GCP region for cluster"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
  description = "Availability zones for node distribution"
}

variable "cluster_name" {
  type        = string
  description = "Name of the GKE cluster"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.27"
  description = "Kubernetes version"
}

variable "environment" {
  type        = string
  description = "Environment name (qac, dev, stg, prd)"
}

variable "team" {
  type        = string
  description = "Team owning the cluster"
}

variable "cost_center" {
  type        = string
  description = "Cost center for billing"
}

variable "subnet_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  description = "Primary subnet CIDR"
}

variable "pods_cidr" {
  type        = string
  default     = "10.4.0.0/14"
  description = "Pod subnet CIDR"
}

variable "services_cidr" {
  type        = string
  default     = "10.8.0.0/20"
  description = "Service subnet CIDR"
}

variable "admin_cidr_block" {
  type        = string
  description = "CIDR block for admin access to API server"
}

variable "machine_type" {
  type        = string
  default     = "e2-standard-4"
  description = "Node machine type"
}

variable "initial_node_count" {
  type        = number
  default     = 3
  description = "Initial number of nodes"
}

variable "min_node_count" {
  type        = number
  default     = 1
  description = "Minimum nodes for autoscaling"
}

variable "max_node_count" {
  type        = number
  default     = 10
  description = "Maximum nodes for autoscaling"
}
```

## Deployment

```bash
# Initialize Terraform
terraform init

# Apply cluster configuration
terraform apply \
  -var="gcp_project=$PROJECT_ID" \
  -var="cluster_name=prod-cluster" \
  -var="environment=prd" \
  -var="team=platform" \
  -var="cost_center=engineering" \
  -var="admin_cidr_block=203.0.113.0/24"

# Get cluster credentials
gcloud container clusters get-credentials prod-cluster \
  --region us-central1 \
  --project $PROJECT_ID

# Verify private cluster
gcloud container clusters describe prod-cluster \
  --region us-central1 \
  --format="value(privateClusterConfig.enablePrivateNodes)"
```

!!! success "Verification"

    - Private control plane: Cannot access API server from public internet
    - Only requests from authorized networks reach API server
    - All nodes use private IPs

## Related Content

- **[Private Cluster Advanced →](private-cluster-advanced.md)** - KMS encryption and advanced config
- **[Workload Identity](../../workload-identity/index.md)** - Pod-to-GCP authentication
- **[Network Security](../network-security/index.md)** - VPC networking and network policies
- **[IAM Configuration](../iam-configuration/index.md)** - Least-privilege access control
