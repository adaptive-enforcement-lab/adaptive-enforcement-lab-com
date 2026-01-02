---
title: Private GKE Cluster Overview
description: Configure private GKE clusters with isolated control planes, VPC networking, secondary IP ranges, and Cloud KMS encryption for secure production workloads.
---

# Private GKE Cluster Overview

Private clusters prevent unauthenticated access to the Kubernetes API server. All traffic is routed through a Private Service Connect endpoint or Cloud NAT.

!!! warning "Public Cluster Risk"

    Public control planes expose your cluster API to the internet. Even with strong authentication, this increases attack surface and is not recommended for production.

## Setup Guides

### Basic Configuration

Start with the basic private cluster setup including VPC networking and custom node pools.

**[Private Cluster Setup →](private-cluster-setup.md)**

Key features:

- Private control plane configuration
- VPC networking with secondary IP ranges
- Custom node pools with security hardening
- Workload Identity enablement

---

### Advanced Security

Add KMS encryption, Binary Authorization, and enhanced monitoring to your cluster.

**[Advanced Configuration →](private-cluster-advanced.md)**

Key features:

- Cloud KMS encryption for etcd
- Binary Authorization for image verification
- Private endpoint access
- Cloud Armor integration
- Security posture monitoring

---

## Quick Start

Basic private cluster deployment:

```bash
# Initialize Terraform
terraform init

# Deploy cluster
terraform apply \
  -var="gcp_project=$PROJECT_ID" \
  -var="cluster_name=prod-cluster" \
  -var="environment=prd"

# Get credentials
gcloud container clusters get-credentials prod-cluster \
  --region us-central1 \
  --project $PROJECT_ID
```

## Related Content

- **[Workload Identity](../../workload-identity/index.md)** - Pod-to-GCP authentication
- **[Network Security](../network-security/index.md)** - VPC networking and network policies
- **[IAM Configuration](../iam-configuration/index.md)** - Least-privilege access control
