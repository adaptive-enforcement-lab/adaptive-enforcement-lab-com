---
title: Cluster Configuration
description: Enable Workload Identity on GKE clusters and configure node pools with metadata server protection and network policy enforcement for production environments.
---

# Cluster Configuration

GKE clusters require explicit Workload Identity enablement. This involves cluster-level configuration and node pool settings.

## Enable on Cluster Creation

```bash
# Create cluster with Workload Identity enabled
gcloud container clusters create my-cluster \
  --zone us-central1-a \
  --workload-pool=PROJECT_ID.svc.id.goog \
  --num-nodes 3
```

The `--workload-pool` flag enables federation. Replace `PROJECT_ID` with your GCP project ID.

!!! tip "Workload Pool Format"

    The workload pool is always `PROJECT_ID.svc.id.goog`. This is the trust domain for the cluster.

## Enable on Existing Cluster

```bash
# Update existing cluster
gcloud container clusters update my-cluster \
  --workload-pool=PROJECT_ID.svc.id.goog \
  --zone us-central1-a
```

This enables the feature cluster-wide with zero downtime.

!!! warning "Node Pool Configuration"

    Existing nodes must be recreated to use Workload Identity. Update node pools to set `workload_metadata_config.mode = GKE_METADATA`.

## Node Pool Configuration

### New Node Pool

```bash
# Create node pool with Workload Identity enabled
gcloud container node-pools create workload-identity-pool \
  --cluster=my-cluster \
  --zone=us-central1-a \
  --workload-metadata=GKE_METADATA \
  --num-nodes=3
```

### Update Existing Node Pool

```bash
# Update existing node pool
gcloud container node-pools update default-pool \
  --cluster=my-cluster \
  --zone=us-central1-a \
  --workload-metadata=GKE_METADATA
```

!!! danger "Node Replacement Required"

    Updating `workload-metadata` requires node recreation. Pods will be rescheduled. Plan for disruption.

## Terraform Configuration

For infrastructure-as-code:

```hcl
# Enable Workload Identity on GKE cluster
resource "google_container_cluster" "primary" {
  name                     = "my-cluster"
  location                 = "us-central1-a"
  initial_node_count       = 3
  remove_default_node_pool = true

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

# Create node pool with Workload Identity enabled
resource "google_container_node_pool" "primary_nodes" {
  name       = "workload-identity-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    machine_type = "e2-medium"

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
```

## Verification

```bash
# 1. Verify cluster has Workload Identity enabled
gcloud container clusters describe my-cluster --zone us-central1-a \
  | grep workloadPool

# Expected output: workloadPool: PROJECT_ID.svc.id.goog

# 2. Verify node pool metadata configuration
gcloud container node-pools describe default-pool \
  --cluster=my-cluster \
  --zone=us-central1-a \
  | grep workloadMetadataConfig

# Expected output: mode: GKE_METADATA

# 3. Test from pod
kubectl run -it --rm debug \
  --image=google/cloud-sdk:slim \
  --restart=Never \
  -- curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity
```

!!! success "Expected Behavior"

    The metadata server should return a JWT token instead of the Compute Engine default service account.

## Security Considerations

### Metadata Server Protection

Workload Identity changes how the metadata server behaves:

```bash
# Before Workload Identity (Compute Engine default)
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token

# Returns: Compute Engine default service account token (broad permissions)

# After Workload Identity (GKE_METADATA mode)
curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token

# Returns: Token for the Kubernetes ServiceAccount's bound GCP service account
```

!!! warning "Default Service Account Access"

    With `GKE_METADATA` mode, pods can no longer access the node's service account. This is intentional—it prevents privilege escalation.

### Network Policy

Restrict metadata server access to specific pods:

```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-metadata-server
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32  # Block metadata server
```

Only allow specific pods:

```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-metadata-for-app
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: trusted-app
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 169.254.169.254/32  # Allow metadata server
    ports:
    - protocol: TCP
      port: 80
```

## Cluster Upgrade Considerations

### Before Upgrade

```bash
# Verify Workload Identity is enabled
gcloud container clusters describe my-cluster --zone us-central1-a \
  --format="value(workloadIdentityConfig.workloadPool)"

# Check node pool metadata mode
gcloud container node-pools list --cluster=my-cluster --zone=us-central1-a \
  --format="table(name,config.workloadMetadataConfig.mode)"
```

### During Upgrade

```bash
# Upgrade cluster control plane first
gcloud container clusters upgrade my-cluster \
  --master \
  --cluster-version=1.28 \
  --zone=us-central1-a

# Then upgrade node pools
gcloud container clusters upgrade my-cluster \
  --node-pool=default-pool \
  --zone=us-central1-a
```

!!! tip "Workload Identity Persists"

    Workload Identity configuration persists across cluster upgrades. No reconfiguration needed.

## Related Configuration

- **[Service Account Binding](service-account-binding.md)** - Create service accounts and IAM bindings
- **[Pod Configuration](pod-configuration.md)** - Deploy workloads and common access patterns
- **[Troubleshooting](troubleshooting.md)** - Debug cluster configuration issues

## References

- [Workload Identity Setup](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Node Pool Configuration](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#node_pools)
- [Terraform GKE Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
