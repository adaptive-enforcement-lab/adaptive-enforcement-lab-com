---
description: >-
  OPA Gatekeeper storage class templates. Enforce approved storage classes and PVC size constraints with complete Rego implementations.
tags:
  - opa
  - gatekeeper
  - storage-class
  - pvc
  - kubernetes
  - templates
---

# OPA Storage Class Templates

OPA/Gatekeeper constraint templates for storage governance. Enforce approved storage classes, prevent expensive storage tiers, and control PVC sizes.

!!! warning "Storage Costs Add Up Fast"
    Uncontrolled PVC creation with premium storage classes can drive up cloud costs. Enforce storage class governance to control expenses.

---

## Template 5: Storage Class Restrictions

Enforces usage of approved storage classes in PersistentVolumeClaims. Prevents expensive or deprecated storage classes from being used.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sallowedstorageclass
spec:
  crd:
    spec:
      names:
        kind: K8sAllowedStorageClass
      validation:
        openAPIV3Schema:
          properties:
            allowedStorageClasses:
              type: array
              items:
                type: string
              description: "List of approved storage class names"
            blockedStorageClasses:
              type: array
              items:
                type: string
              description: "List of blocked storage class names (e.g., deprecated)"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sallowedstorageclass

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "PersistentVolumeClaim"
          storage_class := input.review.object.spec.storageClassName
          count(input.parameters.allowedStorageClasses) > 0
          not allowed_storage_class(storage_class)
          msg := sprintf("Storage class %v is not in the allowed list: %v",
            [storage_class, input.parameters.allowedStorageClasses])
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "PersistentVolumeClaim"
          storage_class := input.review.object.spec.storageClassName
          count(input.parameters.blockedStorageClasses) > 0
          blocked_storage_class(storage_class)
          msg := sprintf("Storage class %v is blocked. Use an approved storage class instead.",
            [storage_class])
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "PersistentVolumeClaim"
          not input.review.object.spec.storageClassName
          count(input.parameters.allowedStorageClasses) > 0
          msg := "PersistentVolumeClaim must specify a storageClassName"
        }

        allowed_storage_class(class) {
          allowed := input.parameters.allowedStorageClasses[_]
          class == allowed
        }

        blocked_storage_class(class) {
          blocked := input.parameters.blockedStorageClasses[_]
          class == blocked
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sAllowedStorageClass
metadata:
  name: allowed-storage-classes
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["PersistentVolumeClaim"]
  parameters:
    allowedStorageClasses:
      - "gp3"           # AWS EBS gp3 (general purpose)
      - "standard-rwo"  # GKE standard persistent disk
      - "managed-csi"   # Azure managed disk
    blockedStorageClasses:
      - "io2"           # AWS provisioned IOPS (expensive)
      - "premium-rwo"   # GKE premium SSD (expensive)
      - "gp2"           # AWS EBS gp2 (deprecated, use gp3)
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `allowedStorageClasses` | Cloud-specific defaults | Approved storage classes (cost-effective) |
| `blockedStorageClasses` | Expensive/deprecated | Explicitly blocked storage classes |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-allowed-storage-class.yaml

# Verify installation
kubectl get constrainttemplates k8sallowedstorageclass
kubectl get k8sallowedstorageclass

# Test with blocked storage class (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: io2  # Blocked expensive storage
  resources:
    requests:
      storage: 10Gi
EOF

# Test with allowed storage class (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3  # Allowed cost-effective storage
  resources:
    requests:
      storage: 10Gi
EOF

# Check violations
kubectl get k8sallowedstorageclass allowed-storage-classes -o yaml

# Audit PVCs with unapproved storage classes
kubectl get pvc -A -o json | jq -r '
  .items[] |
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.storageClassName)"
' | grep -v -E '(gp3|standard-rwo|managed-csi)$'
```

### Use Cases

1. **Cost Control**: Block expensive premium SSD storage classes
2. **Migration Enforcement**: Deprecate old storage classes (gp2 → gp3)
3. **Performance Guarantees**: Ensure production uses appropriate storage tiers
4. **Vendor Lock-in Prevention**: Standardize on CSI storage classes
5. **Compliance**: Enforce encrypted storage classes for sensitive data

---

## Advanced Example: PVC Size Constraints

Extended policy enforcing minimum and maximum PVC sizes to prevent cost overruns and tiny inefficient volumes.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8spvcsizeconstraints
spec:
  crd:
    spec:
      names:
        kind: K8sPVCSizeConstraints
      validation:
        openAPIV3Schema:
          properties:
            minSize:
              type: string
              description: "Minimum PVC size (e.g., '1Gi')"
            maxSize:
              type: string
              description: "Maximum PVC size (e.g., '100Gi')"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8spvcsizeconstraints

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "PersistentVolumeClaim"
          requested := input.review.object.spec.resources.requests.storage
          min_size := input.parameters.minSize
          to_bytes(requested) < to_bytes(min_size)
          msg := sprintf("PVC size %v is below minimum %v", [requested, min_size])
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "PersistentVolumeClaim"
          requested := input.review.object.spec.resources.requests.storage
          max_size := input.parameters.maxSize
          to_bytes(requested) > to_bytes(max_size)
          msg := sprintf("PVC size %v exceeds maximum %v. Request approval for larger volumes.",
            [requested, max_size])
        }

        # Convert storage units to bytes
        to_bytes(str) = num {
          endswith(str, "Ti")
          num := to_number(trim_suffix(str, "Ti")) * 1024 * 1024 * 1024 * 1024
        }
        to_bytes(str) = num {
          endswith(str, "Gi")
          num := to_number(trim_suffix(str, "Gi")) * 1024 * 1024 * 1024
        }
        to_bytes(str) = num {
          endswith(str, "Mi")
          num := to_number(trim_suffix(str, "Mi")) * 1024 * 1024
        }
        to_bytes(str) = num {
          endswith(str, "Ki")
          num := to_number(trim_suffix(str, "Ki")) * 1024
        }
        to_bytes(str) = num {
          not contains(str, "i")
          num := to_number(str)
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sPVCSizeConstraints
metadata:
  name: pvc-size-constraints
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["PersistentVolumeClaim"]
  parameters:
    minSize: "1Gi"    # Prevent tiny volumes (inefficient)
    maxSize: "100Gi"  # Require approval for large volumes
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `minSize` | `1Gi` | Minimum PVC size (prevent inefficient tiny volumes) |
| `maxSize` | `100Gi` | Maximum PVC size (require approval for larger) |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-pvc-size-constraints.yaml

# Verify installation
kubectl get constrainttemplates k8spvcsizeconstraints
kubectl get k8spvcsizeconstraints

# Test with oversized PVC (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: large-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 500Gi  # Exceeds maximum
EOF

# Test with valid size (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: normal-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 20Gi  # Within limits
EOF

# Audit PVCs exceeding size limits
kubectl get pvc -A -o json | jq -r '
  .items[] |
  select(.spec.resources.requests.storage | tonumber > 100) |
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.resources.requests.storage)"
'
```

### Use Cases

1. **Cost Control**: Prevent accidental creation of multi-terabyte volumes
2. **Resource Optimization**: Discourage tiny inefficient volumes under 1Gi
3. **Approval Workflow**: Force teams to request approval for large storage
4. **Capacity Planning**: Ensure cluster has sufficient storage capacity
5. **Best Practices**: Encourage right-sized storage allocation

---

## Storage Class Selection Guide

Choosing the right storage class for your workload:

| Use Case | AWS | GCP | Azure | Characteristics |
|----------|-----|-----|-------|----------------|
| **Development** | gp3 | standard-rwo | managed-csi | Cost-effective, moderate performance |
| **Production Databases** | io2 | pd-ssd | premium-ssd-v2 | High IOPS, low latency |
| **Logs & Backups** | st1 | standard-rwo | standard-lrs | Throughput-optimized, low cost |
| **Ephemeral** | gp3 | balanced-pd | managed-csi | Fast ephemeral volumes |
| **Compliance** | gp3-encrypted | pd-ssd-encrypted | managed-csi-encrypted | Encryption at rest required |

### Migration Path: gp2 → gp3 (AWS)

AWS gp3 offers better performance at lower cost than gp2:

```bash
# Find PVCs using deprecated gp2
kubectl get pvc -A -o json | jq -r '
  .items[] |
  select(.spec.storageClassName == "gp2") |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Update storage class allowlist to block gp2
kubectl patch k8sallowedstorageclass allowed-storage-classes --type='json' -p='[
  {"op": "add", "path": "/spec/parameters/blockedStorageClasses/-", "value": "gp2"}
]'
```

---

## Related Resources

- **[OPA Resource Governance Templates →](governance.md)** - Resource limits and quota enforcement
- **[OPA LimitRange Templates →](limitrange.md)** - Default resource limits and ephemeral storage
- **[OPA Pod Security Templates →](../pod-security/overview.md)** - Privileged containers and host namespaces
- **[Kyverno Storage Templates →](../resource/storage.md)** - Kubernetes-native alternative
- **[Decision Guide →](../../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
