---
title: Kyverno Pod Security Templates
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

## Template 2: Host Namespace Restrictions

Prevents containers from accessing host namespaces (network, PID, IPC). Blocking host namespace access isolates containers from the underlying node and other workloads.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-host-namespaces
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-host-network
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Using host network is not allowed"
        pattern:
          spec:
            template?:
              spec:
                hostNetwork: false
    - name: check-host-pid
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Using host PID namespace is not allowed"
        pattern:
          spec:
            template?:
              spec:
                hostPID: false
    - name: check-host-ipc
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Using host IPC namespace is not allowed"
        pattern:
          spec:
            template?:
              spec:
                hostIPC: false
    - name: check-host-ports
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
      validate:
        message: "Host ports are restricted to monitoring workloads only"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[].ports[].hostPort || `0` }}"
                operator: GreaterThan
                value: 0
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for testing before enforcement |
| `hostNetwork` | `false` | Block host network access |
| `hostPID` | `false` | Block host PID namespace access |
| `hostIPC` | `false` | Block host IPC namespace access |
| `excludeResources` | None | Exempt specific namespaces (e.g., CNI plugins) |

### Validation Commands

```bash
# Apply policy
kubectl apply -f host-namespace-policy.yaml

# Test with hostNetwork (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "hostNetwork": true
  }
}'

# Test with hostPID (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "hostPID": true
  }
}'

# Check policy violations
kubectl get clusterpolicies restrict-host-namespaces
kubectl describe clusterpolicy restrict-host-namespaces
```

### Use Cases

1. **Multi-tenant Isolation**: Prevent containers from accessing each other's processes or network
2. **Container Escape Prevention**: Block common container breakout techniques
3. **PCI-DSS Compliance**: Enforce network segmentation requirements
4. **Zero Trust Networks**: Enforce container-level network isolation

---

## Related Resources

- **[Kyverno Privilege Escalation Prevention →](privileges.md)** - Block privilege escalation
- **[Kyverno Pod Security Profiles →](profiles.md)** - Seccomp and AppArmor enforcement
- **[Kyverno Image Validation →](../image/validation.md)** - Registry allowlists and tag validation
- **[Kyverno Resource Limits →](../resource/limits.md)** - CPU and memory enforcement
- **[Kyverno Labels →](../labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
