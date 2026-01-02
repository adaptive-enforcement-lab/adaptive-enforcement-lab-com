---
description: >-
  Enforce CPU and memory resource limits for all Kubernetes workloads with Kyverno policies preventing resource exhaustion and noisy neighbor OOM kill problems.
tags:
  - kyverno
  - resource-limits
  - kubernetes
  - templates
---

# Kyverno Resource Limits Templates

Ensures all workloads define CPU and memory requests and limits. Prevents resource starvation and noisy neighbor problems.

!!! danger "No Limits Equals Cluster Instability"
    A single pod without memory limits can OOM kill an entire node. Enforce limits on every container, no exceptions.

---

## Template 3: Resource Limits and Requests Enforcement

Ensures all workloads define CPU and memory requests and limits. Prevents resource starvation and noisy neighbor problems.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-resources
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
        message: "CPU and memory requests and limits must be defined"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - resources:
                      limits:
                        memory: "?*"
                        cpu: "?*"
                      requests:
                        memory: "?*"
                        cpu: "?*"
    - name: validate-resource-ranges
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
        message: "Memory limits must be between 128Mi and 4Gi; CPU limits must be between 100m and 4000m"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - resources:
                      limits:
                        memory: "128Mi | 256Mi | 512Mi | 1Gi | 2Gi | 4Gi"
                        cpu: "100m | 200m | 500m | 1000m | 2000m | 4000m"
    - name: validate-requests-less-than-limits
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
        message: "Memory and CPU requests must be less than limits"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - resources:
                      requests:
                        memory: "?*"
                        cpu: "?*"
                      limits:
                        memory: "?*"
                        cpu: "?*"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[0].resources.requests.memory }}"
                operator: GreaterThan
                value: "{{ request.object.spec.template.spec.containers[0].resources.limits.memory }}"
              - key: "{{ request.object.spec.template.spec.containers[0].resources.requests.cpu }}"
                operator: GreaterThan
                value: "{{ request.object.spec.template.spec.containers[0].resources.limits.cpu }}"
    - name: validate-init-containers
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
        message: "Init containers must also define resource requests and limits"
        pattern:
          spec:
            (template)?:
              spec:
                initContainers:
                  - resources:
                      limits:
                        memory: "?*"
                        cpu: "?*"
                      requests:
                        memory: "?*"
                        cpu: "?*"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `memory-range` | `128Mi` to `4Gi` | Adjust for workload profile |
| `cpu-range` | `100m` to `4000m` | Adjust for application needs |
| `exclude-namespaces` | `kube-system`, `kube-public` | Add dev/test namespaces if needed |
| `enforce-mode` | `audit` first | Switch to `enforce` after validation |

### Validation Commands

```bash
# Apply policy
kubectl apply -f resource-limits-policy.yaml

# Test pod without limits (should fail in enforce mode)
kubectl run test --image=nginx -n default

# Test pod with proper limits (should pass)
kubectl run test --image=nginx -n default \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=500m,memory=512Mi

# Find pods without resource limits
kubectl get pods -A -o jsonpath='{range .items[?(@.spec.containers[0].resources.limits.memory == null)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\n"}{end}'

# Check policy violations
kubectl logs -n kyverno deployment/kyverno | grep "require-resource-limits"

# Generate resource audit report
kubectl get pods -A -o=custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU-REQ:.spec.containers[0].resources.requests.cpu,CPU-LIM:.spec.containers[0].resources.limits.cpu,MEM-REQ:.spec.containers[0].resources.requests.memory,MEM-LIM:.spec.containers[0].resources.limits.memory
```

### Use Cases

1. **Cluster Stability**: Prevent resource exhaustion and node OutOfMemory conditions
2. **Cost Optimization**: Right-size workloads and identify over-provisioning
3. **Multi-tenant Isolation**: Enforce fair resource distribution across teams
4. **SLA Compliance**: Guarantee resource availability for critical services
5. **Capacity Planning**: Data-driven decisions on node sizing and autoscaling

---

## Related Resources

- **[Kyverno Pod Security →](kyverno-pod-security.md)** - Security contexts and capabilities
- **[Kyverno Image Validation →](kyverno-image-validation.md)** - Registry allowlists and tag validation
- **[Kyverno Labels →](kyverno-labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
