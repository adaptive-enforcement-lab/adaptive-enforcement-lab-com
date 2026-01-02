---
title: VPC-Native Networking
description: Configure container-native IP allocation using GCP Alias IP ranges for direct pod-to-pod communication without additional routing overhead in GKE clusters.
---

# VPC-Native Networking

VPC-native clusters use container-native networking, providing better performance and simpler network policies.

!!! info "Alias IP Ranges"

    VPC-native uses GCP Alias IP ranges, enabling direct pod-to-pod communication without additional routing.

## Verification

```bash
# Verify VPC-native networking
gcloud container clusters describe prod-cluster \
  --region us-central1 \
  --format="value(networkingConfig.useIpAliases)"
# Returns: True

# Check subnet secondary ranges
gcloud compute networks subnets describe prod-cluster-subnet \
  --region us-central1 \
  --format="value(secondaryIpRanges[*])"
```

!!! tip "IP Range Sizing"

    - Nodes: `/24` = 256 IPs (sufficient for most clusters)
    - Pods: `/14` = 262,144 IPs (65,536 per zone in 4 zones)
    - Services: `/20` = 4,096 IPs (typical cluster has < 1,000 services)

## Related Content

- **[Network Policies](network-policies.md)** - Pod-to-pod traffic control
- **[Private Service Connect](private-service-connect.md)** - Secure GCP service access
- **[Cluster Configuration](../cluster-configuration/private-cluster.md)** - Private GKE cluster setup
