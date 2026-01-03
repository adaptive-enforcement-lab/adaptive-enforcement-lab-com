---
description: >-
  Advanced JMESPath patterns for Kyverno. Label transformations, array operations, and string parsing with production examples.
tags:
  - kyverno
  - jmespath
  - policy-as-code
  - kubernetes
  - advanced
---

# Advanced JMESPath Patterns for Kyverno

Advanced JMESPath techniques for complex Kyverno policies. Label transformations, array operations, and string parsing.

!!! abstract "TL;DR"
    Advanced JMESPath enables sophisticated policy logic: dynamic validation based on labels, array filtering across resources, and string manipulation for naming conventions.

---

## Pattern 5: Label and Annotation Transformations

Extract, transform, and validate metadata. Build dynamic rules based on labels.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: label-based-validation
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: cost-center-must-match-namespace
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
      validate:
        message: "cost-center label must match namespace prefix"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.labels.\"cost-center\" || '' }}"
                operator: NotEquals
                value: "{{ request.namespace | split(@, '-')[0] }}"

    - name: validate-label-format
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "Environment label must be one of: dev, staging, prod"
        pattern:
          metadata:
            labels:
              environment: "dev | staging | prod"
```

### Advanced: Dynamic Validation

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: dynamic-label-validation
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: tier-based-replica-count
      match:
        resources:
          kinds:
            - Deployment
      validate:
        message: "High-tier deployments must have >= 3 replicas"
        deny:
          conditions:
            all:
              - key: "{{ request.object.metadata.labels.tier || '' }}"
                operator: Equals
                value: "high"
              - key: "{{ request.object.spec.replicas || `1` }}"
                operator: LessThan
                value: 3
```

### Use Cases

- Cost center tracking and validation
- Environment-based policies (dev/staging/prod)
- Replica requirements based on criticality labels
- Owner/team validation against namespace

---

## Pattern 6: Array Operations

Work with arrays: filter, count, check existence, validate all elements.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: array-operations
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: no-container-uses-host-port
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "Containers must not use host ports"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.containers[?ports[?hostPort]] | length(@) }}"
                operator: GreaterThan
                value: 0

    - name: all-volumes-must-be-typed
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "All volumes must specify a type (configMap, secret, persistentVolumeClaim, etc.)"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.volumes[?!configMap && !secret && !persistentVolumeClaim && !emptyDir] | length(@) }}"
                operator: GreaterThan
                value: 0
```

### Use Cases

- Validate no container uses privileged ports
- Ensure all volumes are properly typed
- Check that all environment variables are from ConfigMaps/Secrets
- Verify no container mounts hostPath volumes

---

## Pattern 7: String Operations

Parse, split, and validate string values. Common for image strings, URLs, and formatted fields.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: string-operations
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-registry-region
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "Images must use us-east or eu-west registries"
        foreach:
          - list: "request.object.spec.containers[]"
            deny:
              conditions:
                any:
                  - key: "{{ element.image | split(@, '.')[0] | contains(@, 'us-east') || element.image | split(@, '.')[0] | contains(@, 'eu-west') }}"
                    operator: Equals
                    value: false

    - name: validate-namespace-naming
      match:
        resources:
          kinds:
            - Namespace
      validate:
        message: "Namespace must follow team-environment-app pattern"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.name | split(@, '-') | length(@) }}"
                operator: NotEquals
                value: 3
```

### Use Cases

- Validate image registry regions
- Parse and validate DNS names
- Enforce naming conventions
- Extract and validate URL schemes

---

## Best Practices

### 1. Start Simple, Add Complexity

```yaml
# Start with basic filter
spec.containers[?image == 'nginx']

# Add multiple conditions
spec.containers[?image == 'nginx' && securityContext.privileged == `true`]

# Extract and transform
spec.containers[?image == 'nginx'].name | [0]
```

### 2. Use Preconditions for Performance

```yaml
# Only evaluate JMESPath if condition met
preconditions:
  any:
    - key: "{{ request.object.metadata.labels.tier || '' }}"
      operator: Equals
      value: "production"
```

### 3. Provide Helpful Error Messages

```yaml
message: |
  Memory limits ({{ request.object.spec.containers[0].resources.limits.memory }})
  must be >= requests ({{ request.object.spec.containers[0].resources.requests.memory }})
```

### 4. Handle Null Values

```yaml
# Provide defaults for optional fields
key: "{{ request.object.metadata.labels.tier || 'default' }}"

# Check for existence before accessing
conditions:
  all:
    - key: "{{ request.object.metadata.labels.tier || '' }}"
      operator: NotEquals
      value: ""
```

### 5. Test Before Deploying

Always test JMESPath expressions with `kyverno jp` CLI and use audit mode before enforce.

```bash
# Test expression
kyverno jp query 'expression'

# Use audit mode first
validationFailureAction: audit
```

---

## Performance Optimization

### Avoid Expensive Operations

```yaml
# BAD: Multiple passes over large arrays
conditions:
  all:
    - key: "{{ request.object.spec.containers | length(@) }}"
      operator: GreaterThan
      value: 0
    - key: "{{ request.object.spec.containers[0].name }}"
      operator: Equals
      value: "app"

# GOOD: Single pass with filter
conditions:
  all:
    - key: "{{ request.object.spec.containers[?name == 'app'] | length(@) }}"
      operator: GreaterThan
      value: 0
```

### Use Preconditions to Skip Evaluation

```yaml
# Skip expensive JMESPath for non-production namespaces
preconditions:
  any:
    - key: "{{ request.namespace }}"
      operator: In
      value: ["prod-east", "prod-west"]
```

### Cache Results with Variables

```yaml
# Instead of repeating expensive expressions
context:
  - name: criticalContainers
    variable:
      jmesPath: request.object.spec.containers[?securityContext.privileged == `true`]

# Use cached variable
conditions:
  any:
    - key: "{{ criticalContainers | length(@) }}"
      operator: GreaterThan
      value: 0
```

---

## Next Steps

- **[Enterprise JMESPath Examples →](enterprise.md)** - Real-world enterprise policies
- **[JMESPath Testing →](testing.md)** - Testing and debugging techniques
- **[JMESPath Reference →](reference.md)** - Complete function reference
- **[JMESPath Patterns (Core) →](patterns.md)** - Core patterns and basics
- **[Kyverno Templates Overview →](../kyverno/index.md)** - Complete template library
- **[Template Library Overview →](index.md)** - Back to main page

---

## External References

- [JMESPath Official Documentation](https://jmespath.org/)
- [Kyverno Variables](https://kyverno.io/docs/writing-policies/variables/)
- [Kyverno Context Variables](https://kyverno.io/docs/writing-policies/external-data-sources/)
