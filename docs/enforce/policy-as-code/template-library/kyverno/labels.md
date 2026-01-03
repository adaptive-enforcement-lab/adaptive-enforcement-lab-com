---
description: >-
  Kyverno mandatory labels templates. Enforce required metadata for observability, cost tracking, and compliance auditing across all workloads.
tags:
  - kyverno
  - labels
  - kubernetes
  - templates
---

# Kyverno Mandatory Labels Templates

Ensures all workloads have required metadata for observability, cost tracking, and compliance auditing.

!!! success "Cost Allocation Wins"
    Mandatory labels turn cost tracking from guesswork into precision. One team saved $80K in cloud spend by accurately attributing waste to specific applications.

---

## Template 4: Mandatory Labels and Annotations

Ensures all workloads have required metadata for observability, cost tracking, and compliance auditing.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels-annotations
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-required-labels
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
          selector:
            matchExpressions:
              - key: app
                operator: DoesNotExist
      validate:
        message: "Label 'app' is required for all workloads"
        pattern:
          metadata:
            labels:
              app: "?*"
    - name: check-required-team-label
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      validate:
        message: "Label 'team' is required for cost tracking and ownership"
        pattern:
          metadata:
            labels:
              team: "?*"
    - name: check-required-version-label
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      validate:
        message: "Label 'version' is required (format: v1.2.3 or latest)"
        pattern:
          metadata:
            labels:
              version: "?*"
    - name: check-required-annotations
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      validate:
        message: "Annotations 'owner' and 'description' are required for all workloads"
        pattern:
          metadata:
            annotations:
              owner: "?*"
              description: "?*"
    - name: validate-label-values
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      validate:
        message: "Label values must be alphanumeric, lowercase, and 63 characters or less"
        pattern:
          metadata:
            labels:
              app: "[a-z0-9][a-z0-9-]*[a-z0-9]"
              team: "[a-z0-9][a-z0-9-]*[a-z0-9]"
    - name: check-environment-label
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      validate:
        message: "Label 'environment' must be one of: dev, staging, production"
        pattern:
          metadata:
            labels:
              environment: "dev | staging | production"
    - name: require-monitoring-annotation
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
      validate:
        message: "Annotation 'prometheus.io/scrape' is required for observability"
        pattern:
          spec:
            (template)?:
              metadata:
                annotations:
                  prometheus.io/scrape: "true"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `required-labels` | `app`, `team`, `version`, `environment` | Modify based on your tagging strategy |
| `required-annotations` | `owner`, `description` | Add compliance tracking fields |
| `label-format` | Lowercase alphanumeric with hyphens | Enforce naming conventions |
| `environment-values` | `dev`, `staging`, `production` | Adjust to your environment names |

### Validation Commands

```bash
# Apply policy
kubectl apply -f labels-annotations-policy.yaml

# Test without required labels (should fail)
kubectl run test --image=nginx -n default

# Test with required labels (should pass)
kubectl run test --image=nginx -n default \
  --labels app=test-app,team=platform,version=v1.0.0,environment=dev \
  -o yaml | kubectl apply -f -

# Audit all workloads missing required labels
kubectl get pods -A -o jsonpath='{range .items[?(@.metadata.labels.app == null)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}MISSING: app{"\n"}{end}'

# Generate label compliance report
kubectl get pods -A \
  -o=custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,APP:.metadata.labels.app,TEAM:.metadata.labels.team,VERSION:.metadata.labels.version

# Check for missing annotations
kubectl get pods -A -o jsonpath='{range .items[?(@.metadata.annotations.owner == null)]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}MISSING: owner annotation{"\n"}{end}'
```

### Use Cases

1. **Cost Allocation**: Track workload costs by team and application
2. **Compliance Auditing**: Ensure all workloads have documented owners
3. **Multi-tenancy**: Enforce team isolation and accountability
4. **Observability**: Automatic Prometheus scrape configuration and APM tags
5. **Incident Response**: Quick owner identification for troubleshooting
6. **GitOps Tracking**: Link workloads back to source repositories and deployment strategies

---

## Related Resources

- **[Kyverno Pod Security →](pod-security/standards.md)** - Security contexts and capabilities
- **[Kyverno Image Validation →](image/validation.md)** - Registry allowlists and tag validation
- **[Kyverno Resource Limits →](resource/limits.md)** - CPU and memory enforcement
- **[Template Library Overview →](index.md)** - Back to main page
