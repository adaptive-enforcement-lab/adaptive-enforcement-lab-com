---
title: Platform Component Examples
description: >
  Replace infrastructure components without downtime. Real-world examples include service mesh migrations, Kubernetes operator upgrades, and storage backend transitions with zero user impact.
---

# Platform Component Examples

Additional examples of the component replacement pattern for infrastructure migrations.

See [Platform Component Replacement](platform-component-replacement.md) for the core pattern and database migration example.

!!! tip "Pattern Consistency"
    All infrastructure component replacements follow the same build-replace-remove workflow. The examples below use different technologies but the same underlying pattern.

---

## Service Mesh Replacement

**Old**: Linkerd
**New**: Istio

```yaml
# Phase 1: Deploy Istio alongside Linkerd
# Phase 2: Migrate namespaces one at a time
# Phase 3: Remove Linkerd annotations
# Phase 4: Uninstall Linkerd

# No application changes
# Service-to-service communication continues
# mTLS preserved throughout
```

## Kubernetes Operator Upgrade

**Old**: Operator v1 (CRD v1alpha1)
**New**: Operator v2 (CRD v1)

```yaml
# Phase 1: Deploy Operator v2 with CRD v1
# Phase 2: Operator v2 converts v1alpha1 → v1
# Phase 3: Existing resources still work (conversion webhook)
# Phase 4: Update manifests to v1 over time
# Phase 5: Remove Operator v1

# Zero downtime for workloads
# CRD conversion handles compatibility
```

## Storage Backend Migration

**Old**: AWS EBS volumes
**New**: AWS EFS shared filesystem

```yaml
# Phase 1: Create EFS filesystem
# Phase 2: Mount EFS alongside EBS
# Phase 3: Sync data from EBS to EFS
# Phase 4: Update PVC to point to EFS
# Phase 5: Verify application reads from EFS
# Phase 6: Remove EBS volumes

# Application sees same mount point
# Data copied in background
```

---

## Related Guides

- **[Platform Component Replacement](platform-component-replacement.md)** - Core pattern and database example
- **[Compatibility Layers](compatibility-layers.md)** - Compatibility patterns for component replacement
- **[Validation and Rollback](validation-rollback.md)** - Validation and rollback strategies
