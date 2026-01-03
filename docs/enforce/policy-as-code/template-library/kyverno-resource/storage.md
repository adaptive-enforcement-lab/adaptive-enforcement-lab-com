---
description: >-
  Enforce ephemeral storage limits and PVC size constraints with Kyverno policies preventing disk exhaustion and runaway storage costs.
tags:
  - kyverno
  - storage
  - ephemeral-storage
  - pvc
  - kubernetes
  - templates
---

# Kyverno Resource Storage Templates

Controls ephemeral storage consumption and persistent volume claim sizes. Prevents disk exhaustion and runaway storage costs.

!!! warning "Ephemeral Storage Can Fill Nodes"
    Pods without ephemeral storage limits can fill node disks, causing node-level failures. Enforce limits on all containers.

---

## Template 3: Ephemeral Storage Limits

Enforces ephemeral storage limits for containers. Ephemeral storage includes writable container layers, logs, and emptyDir volumes.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-ephemeral-storage-limits
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-ephemeral-storage
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
      validate:
        message: "Ephemeral storage requests and limits must be defined for all containers"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - resources:
                      limits:
                        ephemeral-storage: "?*"
                      requests:
                        ephemeral-storage: "?*"
    - name: validate-storage-ranges
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
      validate:
        message: "Ephemeral storage limits must be between 1Gi and 20Gi"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[].resources.limits.['ephemeral-storage'] || request.object.spec.containers[].resources.limits.['ephemeral-storage'] }}"
                operator: NotIn
                value: ["1Gi", "2Gi", "5Gi", "10Gi", "20Gi"]
    - name: validate-emptydir-sizelimit
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
      preconditions:
        any:
          - key: "{{ request.object.spec.template.spec.volumes[?medium == 'Memory'] || request.object.spec.volumes[?medium == 'Memory'] || `[]` }}"
            operator: NotEquals
            value: []
      validate:
        message: "emptyDir volumes with medium=Memory must define sizeLimit"
        pattern:
          spec:
            (template)?:
              spec:
                volumes:
                  - emptyDir:
                      medium: Memory
                      sizeLimit: "?*"
    - name: limit-emptydir-memory
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      exclude:
        resources:
          namespaces:
            - kube-system
      preconditions:
        any:
          - key: "{{ request.object.spec.template.spec.volumes[?emptyDir.medium == 'Memory'].emptyDir.sizeLimit || request.object.spec.volumes[?emptyDir.medium == 'Memory'].emptyDir.sizeLimit || `[]` }}"
            operator: NotEquals
            value: []
      validate:
        message: "emptyDir memory volumes cannot exceed 512Mi to prevent node memory exhaustion"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.volumes[?emptyDir.medium == 'Memory'].emptyDir.sizeLimit || request.object.spec.volumes[?emptyDir.medium == 'Memory'].emptyDir.sizeLimit }}"
                operator: GreaterThan
                value: 512Mi
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ephemeral-storage-range` | `1Gi` to `20Gi` | Adjust for workload disk I/O needs |
| `emptydir-memory-limit` | `512Mi` | Maximum size for tmpfs-backed emptyDir |
| `exclude-namespaces` | `kube-system`, `kube-public` | Exempt system namespaces |
| `validationFailureAction` | `enforce` | Use `audit` for gradual rollout |

### Validation Commands

```bash
# Apply policy
kubectl apply -f ephemeral-storage-policy.yaml

# Test pod without ephemeral storage limits (should fail)
kubectl run test --image=nginx -n default

# Test pod with ephemeral storage limits (should pass)
kubectl run test --image=nginx -n default \
  --overrides='{"spec":{"containers":[{"name":"test","image":"nginx","resources":{"limits":{"ephemeral-storage":"5Gi"},"requests":{"ephemeral-storage":"2Gi"}}}]}}'

# Check node ephemeral storage usage
kubectl top nodes --sort-by=ephemeral-storage

# Find pods without ephemeral storage limits
kubectl get pods -A -o jsonpath='{range .items[?(@.spec.containers[0].resources.limits.ephemeral-storage == null)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

# Monitor ephemeral storage consumption
kubectl describe node <node-name> | grep -A 5 "Allocated resources"
```

### Use Cases

1. **Node Disk Protection**: Prevent pods from filling node disks and causing evictions
2. **Log Volume Control**: Limit container logs that write to ephemeral storage
3. **Build Job Safety**: Enforce storage limits on CI/CD build pods
4. **EmptyDir Volume Management**: Control tmpfs and disk-backed emptyDir volumes
5. **Multi-tenant Quotas**: Fair storage allocation across teams and namespaces

---

## Template 4: PVC Size Constraints

Enforces minimum and maximum sizes for PersistentVolumeClaims. Prevents undersized volumes (causing application failures) and oversized volumes (wasting cloud storage costs).

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-pvc-size-limits
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-pvc-minimum-size
      match:
        resources:
          kinds:
            - PersistentVolumeClaim
      exclude:
        resources:
          namespaces:
            - kube-system
      validate:
        message: "PVC size must be at least 1Gi to ensure usable storage"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.resources.requests.storage }}"
                operator: LessThan
                value: 1Gi
    - name: validate-pvc-maximum-size
      match:
        resources:
          kinds:
            - PersistentVolumeClaim
      exclude:
        resources:
          namespaces:
            - kube-system
      validate:
        message: "PVC size cannot exceed 100Gi without approval. Use storage class with allowVolumeExpansion for large volumes."
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.resources.requests.storage }}"
                operator: GreaterThan
                value: 100Gi
    - name: enforce-storageclass-limits-by-tier
      match:
        resources:
          kinds:
            - PersistentVolumeClaim
          selector:
            matchLabels:
              storage-tier: "premium"
      validate:
        message: "Premium storage tier limited to 50Gi to control costs"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.resources.requests.storage }}"
                operator: GreaterThan
                value: 50Gi
    - name: require-storageclass
      match:
        resources:
          kinds:
            - PersistentVolumeClaim
      exclude:
        resources:
          namespaces:
            - kube-system
            - local-path-storage
      validate:
        message: "PVCs must specify a storageClassName to prevent reliance on default storage class"
        pattern:
          spec:
            storageClassName: "?*"
    - name: block-hostpath-volumes
      match:
        resources:
          kinds:
            - PersistentVolumeClaim
      validate:
        message: "hostPath storage is prohibited in production namespaces for security reasons"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.storageClassName }}"
                operator: In
                value: ["hostpath", "local-path"]
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `pvc-minimum-size` | `1Gi` | Minimum PVC size to prevent unusable volumes |
| `pvc-maximum-size` | `100Gi` | Maximum PVC size before requiring approval |
| `premium-storage-limit` | `50Gi` | Cost control for premium/SSD storage tiers |
| `allowed-storage-classes` | All except `hostpath` | Permitted storage classes per environment |

### Validation Commands

```bash
# Apply policy
kubectl apply -f pvc-size-policy.yaml

# Test PVC below minimum (should fail)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 512Mi
  storageClassName: standard
EOF

# Test PVC within valid range (should pass)
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: standard
EOF

# Audit current PVC sizes
kubectl get pvc -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,SIZE:.spec.resources.requests.storage,STORAGECLASS:.spec.storageClassName

# Calculate total storage consumption per namespace
kubectl get pvc -A -o json | jq -r '.items | group_by(.metadata.namespace) | .[] | "\(.[0].metadata.namespace): \(map(.spec.resources.requests.storage | rtrimstr("Gi") | tonumber) | add)Gi"'

# Check for PVCs without storage class
kubectl get pvc -A -o json | jq -r '.items[] | select(.spec.storageClassName == null) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Use Cases

1. **Cost Control**: Prevent accidental provisioning of expensive large volumes
2. **Storage Quota Enforcement**: Align with cloud provider or on-prem storage limits
3. **Application Safety**: Ensure volumes are large enough for application requirements
4. **Storage Class Governance**: Enforce approved storage classes per environment
5. **Chargeback Accuracy**: Track storage consumption for cost allocation

---

## Related Resources

- **[Kyverno Resource Limits →](limits.md)** - CPU and memory enforcement
- **[Kyverno HPA Requirements →](hpa.md)** - Horizontal Pod Autoscaler enforcement
- **[Kyverno Pod Security →](../kyverno-pod-security/standards.md)** - Security contexts and capabilities
- **[Kyverno Labels →](../kyverno-labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
