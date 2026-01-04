---
title: Kyverno HPA Requirements Templates
description: >-
  Enforce HorizontalPodAutoscaler requirements with Kyverno policies ensuring proper configuration, resource metrics, and scaling boundaries.
tags:
  - kyverno
  - hpa
  - autoscaling
  - kubernetes
  - templates
---
# Kyverno HPA Requirements Templates

Ensures HorizontalPodAutoscalers are properly configured with resource requests, scaling boundaries, and target metrics. Prevents misconfigured autoscalers that fail to scale or cause resource thrashing.

!!! tip "HPA Requires Resource Requests"
    HPAs using resource-based metrics require resource requests on target containers. Without requests, the HPA cannot calculate utilization percentages.

---

## Template 5: HPA Configuration Requirements

Enforces proper HPA configuration including resource requests on target workloads, minimum/maximum replica bounds, and valid target metrics.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-hpa-requirements
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-hpa-replica-bounds
      match:
        resources:
          kinds:
            - HorizontalPodAutoscaler
      validate:
        message: "HPA must define minReplicas >= 2 and maxReplicas <= 50 for stability"
        pattern:
          spec:
            minReplicas: ">=2"
            maxReplicas: "<=50"
    - name: validate-hpa-min-max-relationship
      match:
        resources:
          kinds:
            - HorizontalPodAutoscaler
      validate:
        message: "HPA maxReplicas must be greater than minReplicas"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.maxReplicas }}"
                operator: LessThanOrEquals
                value: "{{ request.object.spec.minReplicas }}"
    - name: require-target-metrics
      match:
        resources:
          kinds:
            - HorizontalPodAutoscaler
      validate:
        message: "HPA must define at least one metric (CPU, memory, or custom)"
        pattern:
          spec:
            metrics:
              - type: "Resource | Pods | Object | External | ContainerResource"
    - name: validate-cpu-target-utilization
      match:
        resources:
          kinds:
            - HorizontalPodAutoscaler
      preconditions:
        any:
          - key: "{{ request.object.spec.metrics[?type == 'Resource' && resource.name == 'cpu'] || `[]` }}"
            operator: NotEquals
            value: []
      validate:
        message: "CPU target utilization must be between 50% and 90% to avoid thrashing"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.metrics[?type == 'Resource' && resource.name == 'cpu'].resource.target.averageUtilization || `0` }}"
                operator: LessThan
                value: 50
              - key: "{{ request.object.spec.metrics[?type == 'Resource' && resource.name == 'cpu'].resource.target.averageUtilization || `0` }}"
                operator: GreaterThan
                value: 90
    - name: validate-memory-target-utilization
      match:
        resources:
          kinds:
            - HorizontalPodAutoscaler
      preconditions:
        any:
          - key: "{{ request.object.spec.metrics[?type == 'Resource' && resource.name == 'memory'] || `[]` }}"
            operator: NotEquals
            value: []
      validate:
        message: "Memory target utilization must be between 60% and 85% to avoid OOM kills"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.metrics[?type == 'Resource' && resource.name == 'memory'].resource.target.averageUtilization || `0` }}"
                operator: LessThan
                value: 60
              - key: "{{ request.object.spec.metrics[?type == 'Resource' && resource.name == 'memory'].resource.target.averageUtilization || `0` }}"
                operator: GreaterThan
                value: 85
    - name: require-scaledown-stabilization
      match:
        resources:
          kinds:
            - HorizontalPodAutoscaler
      validate:
        message: "HPA must define behavior.scaleDown.stabilizationWindowSeconds >= 60 to prevent flapping"
        pattern:
          spec:
            behavior:
              scaleDown:
                stabilizationWindowSeconds: ">=60"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `minReplicas` | `>= 2` | Minimum pods for high availability |
| `maxReplicas` | `<= 50` | Maximum pods to prevent runaway scaling |
| `cpu-target-min` | `50%` | Minimum CPU target to avoid over-scaling |
| `cpu-target-max` | `90%` | Maximum CPU target to maintain headroom |
| `memory-target-min` | `60%` | Minimum memory target |
| `memory-target-max` | `85%` | Maximum memory target to prevent OOM |
| `stabilization-window` | `>= 60s` | Cooldown period for scale-down events |

### Validation Commands

```bash
# Apply policy
kubectl apply -f hpa-requirements-policy.yaml

# Test HPA with invalid minReplicas (should fail)
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: test-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
EOF

# Test HPA with valid configuration (should pass)
kubectl apply -f - <<EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: test-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 75
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
EOF

# Check current HPA status
kubectl get hpa -A

# Describe HPA to see current metrics
kubectl describe hpa <hpa-name> -n <namespace>

# Verify target deployment has resource requests
kubectl get deployment <deployment-name> -o jsonpath='{.spec.template.spec.containers[].resources}'

# Monitor HPA scaling events
kubectl get events --field-selector involvedObject.kind=HorizontalPodAutoscaler --sort-by='.lastTimestamp'
```

### Use Cases

1. **Prevent HPA Misconfiguration**: Block HPAs targeting workloads without resource requests
2. **Cost Control**: Limit maximum replicas to prevent runaway cloud costs
3. **High Availability**: Enforce minimum replicas for production workloads
4. **Scaling Stability**: Require stabilization windows to prevent scaling thrash
5. **Resource Utilization Targets**: Ensure realistic CPU/memory utilization thresholds

### HPA Resource Requests Validation

HPAs using resource-based metrics require the target deployment to have resource requests defined:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: hpa-target-has-requests
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-deployment-has-requests
      match:
        resources:
          kinds:
            - Deployment
      preconditions:
        any:
          - key: "{{ request.object.metadata.labels.autoscaling || 'false' }}"
            operator: Equals
            value: "enabled"
      validate:
        message: "Deployments with autoscaling enabled must define CPU and memory requests for HPA to function"
        pattern:
          spec:
            template:
              spec:
                containers:
                  - resources:
                      requests:
                        cpu: "?*"
                        memory: "?*"
```

Apply this policy alongside the main HPA policy:

```bash
# Label deployment for HPA
kubectl label deployment web autoscaling=enabled

# HPA will fail if deployment lacks resource requests
kubectl autoscale deployment web --cpu-percent=75 --min=2 --max=10
```

### Troubleshooting HPA Issues

Common HPA failures and policy enforcement:

```bash
# Check if target has resource requests
kubectl get deployment <name> -o jsonpath='{.spec.template.spec.containers[].resources}'

# Verify metrics-server is running
kubectl get deployment metrics-server -n kube-system

# Check HPA unable to compute metrics
kubectl describe hpa <name> | grep "unable to compute"

# Test HPA metrics calculation
kubectl top pods -l app=<target-app>

# Force HPA recalculation
kubectl patch hpa <name> -p '{"metadata":{"annotations":{"autoscaling.alpha.kubernetes.io/metrics":"refresh"}}}'
```

---

## Related Resources

- **[Kyverno Resource Limits →](limits.md)** - CPU and memory enforcement (required for HPA)
- **[Kyverno Resource Storage →](storage.md)** - Ephemeral storage and PVC limits
- **[Kyverno Pod Security →](../pod-security/standards.md)** - Security contexts and capabilities
- **[Kyverno Labels →](../labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
