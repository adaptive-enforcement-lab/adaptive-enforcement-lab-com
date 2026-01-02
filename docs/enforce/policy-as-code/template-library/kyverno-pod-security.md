---
description: >-
  Kyverno pod security templates. Enforce pod security standards, prevent privileged containers, require read-only roots, and drop dangerous capabilities.
tags:
  - kyverno
  - pod-security
  - kubernetes
  - templates
---

# Kyverno Pod Security Templates

Enforces pod security standards with sensible defaults for production workloads. Prevents privileged containers, required read-only roots, and enforces security contexts.

!!! warning "Privileged Containers Are Cluster Admin"
    Running a privileged container gives the pod root access to the underlying node. Block them unless you have a documented exception.

---

## Template 1: Pod Security Standards Enforcement

Enforces pod security standards with sensible defaults for production workloads. Prevents privileged containers, required read-only roots, and enforces security contexts.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-privileged-containers
  namespace: kyverno
spec:
  validationFailureAction: enforce  # Use 'audit' for testing
  background: true
  rules:
    - name: check-privileged
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Privileged containers are not allowed"
        pattern:
          spec:
            template?:
              spec:
                containers:
                  - securityContext:
                      privileged: false
    - name: check-capabilities
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Dangerous capabilities must be dropped"
        pattern:
          spec:
            template?:
              spec:
                containers:
                  - securityContext:
                      capabilities:
                        drop:
                          - ALL
    - name: enforce-read-only-filesystem
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
          selector:
            matchLabels:
              security.enforce: "high"
      validate:
        message: "Read-only root filesystem required for high-security workloads"
        pattern:
          spec:
            template?:
              spec:
                containers:
                  - securityContext:
                      readOnlyRootFilesystem: true
    - name: check-run-as-non-root
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Container must not run as root"
        pattern:
          spec:
            template?:
              spec:
                containers:
                  - securityContext:
                      runAsNonRoot: true
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for testing before enforcement |
| `background` | `true` | Apply policy to existing resources |
| `security.enforce` label | `high` | Namespace to apply stricter rules |

### Validation Commands

```bash
# Validate policy syntax
kubectl apply --dry-run=client -f pod-security-policy.yaml

# Apply in audit mode first
kubectl apply -f pod-security-policy.yaml
kubectl logs -f -n kyverno deployment/kyverno

# Generate test pod (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "securityContext": {
      "runAsRoot": true
    }
  }
}'

# Check policy violations
kubectl get clusterpolicies
kubectl describe clusterpolicy restrict-privileged-containers
```

### Use Cases

1. **PCI-DSS Compliance**: Enforce non-root users, read-only filesystems, dropped capabilities
2. **Multi-tenant Clusters**: Prevent privilege escalation across namespace boundaries
3. **Supply Chain Security**: Ensure container images run with minimal privileges
4. **Compliance Audits**: Track all policy violations in audit logs for reporting

---

## Related Resources

- **[Kyverno Image Validation →](kyverno-image-validation.md)** - Registry allowlists and tag validation
- **[Kyverno Resource Limits →](kyverno-resource-limits.md)** - CPU and memory enforcement
- **[Kyverno Labels →](kyverno-labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
