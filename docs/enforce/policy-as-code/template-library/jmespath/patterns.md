---
description: >-
  JMESPath patterns for advanced Kyverno policies. Master data extraction, complex conditions, and cross-field validation with production-tested examples.
tags:
  - kyverno
  - jmespath
  - policy-as-code
  - kubernetes
---

# JMESPath Patterns for Kyverno Policies

Master JMESPath for complex Kyverno policies. Extract data, build conditions, and validate nested Kubernetes resources with production-tested patterns.

!!! abstract "TL;DR"
    JMESPath extends Kyverno beyond simple pattern matching. Use it for complex queries, cross-field validation, and dynamic policy logic. Test with `kyverno jp` CLI before deploying.

---

## Why JMESPath in Kyverno

**Simple pattern matching hits limits fast:**

- Can't compare multiple fields (e.g., requests vs limits)
- Can't validate based on conditionals (e.g., if label exists, then require annotation)
- Can't extract and transform data (e.g., parse image tags)

**JMESPath solves this:**

- Query nested JSON structures
- Build complex boolean logic
- Extract and transform values
- Cross-reference fields dynamically

!!! tip "When to Use JMESPath"
    Use JMESPath when `pattern` or `anyPattern` can't express your validation logic. If you need conditionals, transformations, or cross-field checks, JMESPath is required.

---

## JMESPath Basics

### Projection and Filtering

```yaml
# Extract all container names
spec.template.spec.containers[*].name

# Filter containers with specific image
spec.template.spec.containers[?image == 'nginx'].name

# Check if any container is privileged
spec.template.spec.containers[?securityContext.privileged == `true`]
```

### Boolean Logic

```yaml
# AND condition
length(spec.template.spec.containers[?image == 'nginx' && securityContext.privileged == `true`]) > `0`

# OR condition
length(spec.template.spec.containers[?image == 'nginx' || image == 'redis']) > `0`

# NOT condition
length(spec.template.spec.containers[?image != 'nginx']) == `0`
```

### Data Extraction

```yaml
# Get image tag from full image string
split(@, ':')[1]

# Extract registry from image
split(image, '/')[0]

# Count containers
length(spec.template.spec.containers)
```

---

## Pattern 1: Cross-Field Validation

Validate relationships between multiple fields. Common use case: ensure `requests` don't exceed `limits`.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: validate-resource-ratios
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-memory-limits-exceed-requests
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
      validate:
        message: "Memory limits must be >= memory requests"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[].resources.limits.memory || request.object.spec.containers[].resources.limits.memory }}"
                operator: LessThan
                value: "{{ request.object.spec.template.spec.containers[].resources.requests.memory || request.object.spec.containers[].resources.requests.memory }}"
```

### Use Cases

- Ensure CPU/memory requests don't exceed limits
- Validate replica count matches HPA configuration
- Check that nodeSelector matches tolerations

---

## Pattern 2: Conditional Validation

Apply rules only when specific conditions are met. Example: require annotations if labels exist.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: conditional-annotations
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: require-contact-if-critical
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
      preconditions:
        any:
          - key: "{{ request.object.metadata.labels.criticality || '' }}"
            operator: Equals
            value: "high"
      validate:
        message: "Deployments with criticality=high must have contact annotation"
        pattern:
          metadata:
            annotations:
              contact: "?*"
```

### Advanced Example: Image Registry Enforcement

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-registry-by-namespace
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: production-must-use-prod-registry
      match:
        resources:
          kinds:
            - Pod
            - Deployment
          namespaces:
            - prod-*
      validate:
        message: "Production namespaces must use prod.registry.io"
        foreach:
          - list: "request.object.spec.containers[]"
            deny:
              conditions:
                any:
                  - key: "{{ element.image | split(@, '/')[0] }}"
                    operator: NotEquals
                    value: "prod.registry.io"
```

### Use Cases

- Namespace-specific registry enforcement
- Require PodDisruptionBudgets for StatefulSets with replicas > 3
- Enforce monitoring annotations for high-criticality workloads

---

## Pattern 3: Image Tag Validation

Extract and validate image tags. Prevent `latest` tags, require semantic versioning, enforce digest pinning.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: validate-image-tags
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: disallow-latest-tag
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
      validate:
        message: "Image tag 'latest' is not allowed"
        foreach:
          - list: "request.object.spec.containers[]"
            deny:
              conditions:
                any:
                  - key: "{{ element.image | split(@, ':')[1] || 'latest' }}"
                    operator: Equals
                    value: "latest"

    - name: require-semantic-versioning
      match:
        resources:
          kinds:
            - Deployment
          namespaces:
            - prod-*
      validate:
        message: "Production images must use semantic versioning (vX.Y.Z)"
        foreach:
          - list: "request.object.spec.template.spec.containers[]"
            pattern:
              image: "*/v*.*.*"
```

### Advanced: Digest Pinning

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-digests
spec:
  validationFailureAction: enforce
  background: false
  rules:
    - name: check-digest-presence
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "Images must be pinned to digest (image@sha256:...)"
        foreach:
          - list: "request.object.spec.containers[] | [?image]"
            deny:
              conditions:
                any:
                  - key: "{{ element.image | contains(@, '@sha256:') }}"
                    operator: Equals
                    value: false
```

### Use Cases

- Block `latest` tags in production
- Require semantic versioning for audit trails
- Enforce digest pinning for supply chain security
- Validate image tag naming conventions

---

## Pattern 4: Multi-Container Validation

Validate across all containers and init containers. Ensure consistency, check for required sidecars.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: multi-container-validation
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: all-containers-must-have-resources
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "All containers must define resource requests and limits"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.containers[?!resources.requests.memory] | length(@) }}"
                operator: GreaterThan
                value: 0
              - key: "{{ request.object.spec.containers[?!resources.limits.memory] | length(@) }}"
                operator: GreaterThan
                value: 0

    - name: require-logging-sidecar-for-statefulsets
      match:
        resources:
          kinds:
            - StatefulSet
      validate:
        message: "StatefulSets must include fluent-bit logging sidecar"
        deny:
          conditions:
            all:
              - key: "{{ request.object.spec.template.spec.containers[?name == 'fluent-bit'] | length(@) }}"
                operator: Equals
                value: 0
```

### Use Cases

- Ensure all containers have resource limits
- Require specific sidecars (logging, metrics, security)
- Validate consistent security contexts across containers
- Check that init containers complete required setup

---

## Next Steps

- **[Advanced JMESPath Patterns →](advanced.md)** - Advanced patterns, testing, and debugging
- **[Kyverno Templates Overview →](../kyverno-templates.md)** - Complete template library
- **[Kyverno Pod Security →](../kyverno-pod-security/standards.md)** - Pod security policies
- **[Decision Guide →](../decision-guide.md)** - OPA vs Kyverno
- **[Template Library Overview →](index.md)** - Back to main page

---

## External References

- [JMESPath Official Documentation](https://jmespath.org/)
- [JMESPath Tutorial](https://jmespath.org/tutorial.html)
- [Kyverno JMESPath Guide](https://kyverno.io/docs/writing-policies/jmespath/)
- [kyverno jp CLI Reference](https://kyverno.io/docs/kyverno-cli/#jp)
