---
title: Kyverno Resource Limits Templates
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

## Template 1: Resource Limits and Requests Enforcement

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
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[].resources.limits.memory || request.object.spec.containers[].resources.limits.memory }}"
                operator: NotIn
                value: ["128Mi", "256Mi", "512Mi", "1Gi", "2Gi", "4Gi"]
              - key: "{{ request.object.spec.template.spec.containers[].resources.limits.cpu || request.object.spec.containers[].resources.limits.cpu }}"
                operator: NotIn
                value: ["100m", "200m", "500m", "1000m", "2000m", "4000m"]
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
      preconditions:
        any:
          - key: "{{ request.object.spec.template.spec.initContainers[] || request.object.spec.initContainers[] || `[]` }}"
            operator: NotEquals
            value: []
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
| `validationFailureAction` | `enforce` | Use `audit` first for testing |

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

## Template 2: CPU and Memory Ratio Enforcement

Enforces request-to-limit ratios to prevent resource overcommitment. Ensures requests are not too low (wasting capacity) or too close to limits (risking throttling).

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-resource-ratios
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-memory-request-minimum
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
        message: >-
          Memory request must be at least 50% of limit.
          Use annotations to specify ratio requirements.
        deny:
          conditions:
            any:
              - key: >-
                  {{ request.object.spec.template.spec.containers[0].resources.requests.memory
                  || request.object.spec.containers[0].resources.requests.memory }}
                operator: LessThan
                value: >-
                  {{ multiply(to_number(
                  request.object.spec.template.spec.containers[0].resources.limits.memory
                  || request.object.spec.containers[0].resources.limits.memory), 0.5) }}
    - name: validate-cpu-request-minimum
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
        message: >-
          CPU request must be at least 25% of limit.
          Use annotations to specify ratio requirements.
        deny:
          conditions:
            any:
              - key: >-
                  {{ request.object.spec.template.spec.containers[0].resources.requests.cpu
                  || request.object.spec.containers[0].resources.requests.cpu }}
                operator: LessThan
                value: >-
                  {{ multiply(to_number(
                  request.object.spec.template.spec.containers[0].resources.limits.cpu
                  || request.object.spec.containers[0].resources.limits.cpu), 0.25) }}
    - name: enforce-burstable-qos
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
          selector:
            matchLabels:
              qos-class: "burstable"
      validate:
        message: "Burstable QoS requires requests < limits (current: requests == limits)"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[0].resources.requests.memory }}"
                operator: Equals
                value: "{{ request.object.spec.template.spec.containers[0].resources.limits.memory }}"
              - key: "{{ request.object.spec.template.spec.containers[0].resources.requests.cpu }}"
                operator: Equals
                value: "{{ request.object.spec.template.spec.containers[0].resources.limits.cpu }}"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `memory-ratio-min` | `0.5` (50%) | Minimum memory request as % of limit |
| `memory-ratio-max` | `1.0` (100%) | Maximum memory request as % of limit |
| `cpu-ratio-min` | `0.25` (25%) | Minimum CPU request as % of limit |
| `cpu-ratio-max` | `1.0` (100%) | Maximum CPU request as % of limit |
| `qos-class-enforcement` | Optional | Enforce Guaranteed or Burstable QoS |

### Validation Commands

```bash
# Apply policy
kubectl apply -f resource-ratio-policy.yaml

# Test with low ratio (should fail - request 10% of limit)
kubectl run test --image=nginx -n default \
  --requests=cpu=10m,memory=50Mi \
  --limits=cpu=100m,memory=512Mi

# Test with valid ratio (should pass - request 50% of limit)
kubectl run test --image=nginx -n default \
  --requests=cpu=50m,memory=256Mi \
  --limits=cpu=100m,memory=512Mi

# Audit current ratio violations
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[0].resources.limits.memory != null) | "\(.metadata.namespace)/\(.metadata.name): \((.spec.containers[0].resources.requests.memory | tonumber) / (.spec.containers[0].resources.limits.memory | tonumber) * 100)%"'

# Check QoS class distribution
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,QOS:.status.qosClass
```

### Use Cases

1. **Prevent Overcommitment**: Block deployments with very low requests that would oversubscribe nodes
2. **CPU Throttling Prevention**: Ensure requests are high enough to avoid excessive throttling
3. **Capacity Planning**: Enforce predictable resource utilization for autoscaling calculations
4. **Cost Attribution**: Accurate chargeback based on reserved (requested) resources
5. **QoS Enforcement**: Guarantee specific quality-of-service classes (Guaranteed vs Burstable)

---

## Related Resources

- **[Kyverno Resource Storage →](storage.md)** - Ephemeral storage and PVC limits
- **[Kyverno HPA Requirements →](hpa.md)** - Horizontal Pod Autoscaler enforcement
- **[Kyverno Pod Security →](../pod-security/standards.md)** - Security contexts and capabilities
- **[Kyverno Image Validation →](../image/validation.md)** - Registry allowlists and tag validation
- **[Kyverno Labels →](../labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
