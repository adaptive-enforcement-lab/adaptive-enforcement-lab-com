---
title: JMESPath Testing and Debugging
description: >-
  JMESPath testing and debugging for Kyverno. Testing techniques, debugging tools, common pitfalls, and troubleshooting guide.
tags:
  - kyverno
  - jmespath
  - policy-as-code
  - kubernetes
  - testing
---
# JMESPath Testing and Debugging

Complete testing guide for JMESPath in Kyverno policies. Testing techniques, debugging tools, and troubleshooting.

!!! abstract "TL;DR"
    Always test JMESPath expressions with `kyverno jp` CLI before deploying. Use audit mode first, provide defaults for null values, and validate with real resources.

---

## Testing with kyverno jp CLI

### Installation

```bash
# Install via kubectl krew
kubectl krew install kyverno

# Verify installation
kyverno version
```

### Basic Testing

```bash
# Test JMESPath query
echo '{"spec": {"containers": [{"name": "nginx", "image": "nginx:latest"}]}}' | \
  kyverno jp query 'spec.containers[0].image | split(@, `:`) [1]'

# Output: "latest"

# Test with file input
cat pod.json | kyverno jp query 'spec.containers[*].name'

# Test multiple queries
echo '{"metadata": {"labels": {"env": "prod"}}}' | \
  kyverno jp query 'metadata.labels.env'
```

### Interactive Testing

```bash
# Start interactive mode
kyverno jp query -i

# Enter JSON and query interactively
> {"spec": {"replicas": 3}}
> spec.replicas
3
```

### Testing Functions

```bash
# Test length function
echo '{"items": ["a", "b", "c"]}' | \
  kyverno jp query 'length(items)'

# Test split and array access
echo '{"image": "nginx:1.21"}' | \
  kyverno jp query 'image | split(@, `:`) [1]'

# Test contains
echo '{"image": "nginx:latest"}' | \
  kyverno jp query 'contains(image, `nginx`)'
```

---

## Testing in Policy Context

### Dry-Run Testing

```bash
# Create test resource
cat <<EOF > test-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pod
  labels:
    environment: dev
spec:
  containers:
  - name: nginx
    image: nginx:latest
    resources:
      requests:
        memory: "64Mi"
      limits:
        memory: "128Mi"
EOF

# Test policy against resource
kyverno apply policy.yaml --resource test-pod.yaml
```

### Audit Mode Testing

```yaml
# Deploy policy in audit mode first
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: test-policy
spec:
  validationFailureAction: audit  # Use audit, not enforce
  background: true
  rules:
    - name: test-rule
      # ... policy rules
```

```bash
# Apply policy
kubectl apply -f policy.yaml

# Check policy reports
kubectl get policyreport -A
kubectl describe policyreport -n default

# Watch for violations
kubectl logs -f -n kyverno deployment/kyverno | grep -i jmespath
```

### Testing with Multiple Resources

```bash
# Test against directory of resources
kyverno apply policy.yaml --resource ./test-resources/

# Test specific resource types
kyverno apply policy.yaml --resource <(kubectl get deployment -o yaml)
```

---

## Debugging Techniques

### Enable Debug Logging

```yaml
# Add to Kyverno deployment
spec:
  template:
    spec:
      containers:
      - name: kyverno
        args:
          - --v=6  # Verbose logging
```

```bash
# Watch debug logs
kubectl logs -f -n kyverno deployment/kyverno --tail=100
```

### Test JMESPath Expressions Incrementally

```bash
# Start simple
echo '{"spec": {"containers": [{"image": "nginx:latest"}]}}' | \
  kyverno jp query 'spec.containers'

# Add array access
kyverno jp query 'spec.containers[0]'

# Add field extraction
kyverno jp query 'spec.containers[0].image'

# Add string manipulation
kyverno jp query 'spec.containers[0].image | split(@, `:`)[1]'
```

### Validate JSON Structure

```bash
# Pretty-print JSON to verify structure
kubectl get pod test-pod -o json | jq .

# Extract specific fields
kubectl get deployment nginx -o json | \
  jq '.spec.template.spec.containers[].image'
```

---

## Common Pitfalls and Solutions

### Pitfall 1: Backtick Literals

!!! warning "Backtick Required for Literals"
    JMESPath requires backticks for numbers, booleans, and null values in expressions.

```yaml
# WRONG: Missing backticks
containers[?privileged == true]

# CORRECT: Use backticks
containers[?privileged == `true`]

# WRONG: Number without backticks
spec.replicas > 3

# CORRECT: Use backticks for numbers
spec.replicas > `3`
```

### Pitfall 2: Null Handling

!!! warning "Always Provide Defaults"
    Optional fields return null. Use OR operator to provide defaults.

```yaml
# WRONG: Fails if label doesn't exist
key: "{{ request.object.metadata.labels.tier }}"

# CORRECT: Provide default
key: "{{ request.object.metadata.labels.tier || '' }}"

# CORRECT: Numeric default (note: backtick is part of the value, not inside quotes)
key: "{{ request.object.spec.replicas || `1` }}"
```

### Pitfall 3: Array Projection

!!! warning "Understand [*] vs []"
    `[*]` flattens arrays, `[]` preserves structure.

```yaml
# Flattens: Returns ["nginx", "redis"]
containers[*].name

# Preserves structure: Returns [{"name": "nginx"}, {"name": "redis"}]
containers[]

# Filter then project
containers[?image == 'nginx'].name
```

### Pitfall 4: String Splitting

!!! warning "Split Returns Array"
    Always access array elements after split.

```yaml
# WRONG: Returns array, not string
image | split(@, `:`)

# CORRECT: Access specific element
image | split(@, `:`)[1]

# Get first element (registry)
image | split(@, `/`)[0]
```

---

## Policy Report Analysis

### Get Policy Reports

```bash
# List all policy reports
kubectl get policyreport -A

# Get specific namespace report
kubectl get policyreport -n production

# Describe report details
kubectl describe policyreport -n production
```

### Query Report Details

```bash
# Get failed policies
kubectl get policyreport -A -o json | \
  jq '.items[] | select(.summary.fail > 0)'

# Get policy violations
kubectl get policyreport polr-ns-production -o json | \
  jq '.results[] | select(.result == "fail")'

# Count violations by policy
kubectl get policyreport -A -o json | \
  jq '.items[].results[] | select(.result == "fail") | .policy' | \
  sort | uniq -c
```

---

## Troubleshooting

### Policy Not Triggering

```bash
# Check policy is deployed
kubectl get clusterpolicy

# Verify policy status
kubectl describe clusterpolicy policy-name

# Check Kyverno logs
kubectl logs -n kyverno deployment/kyverno
```

### JMESPath Evaluation Errors

```bash
# Enable verbose logging
kubectl set env -n kyverno deployment/kyverno LOG_LEVEL=debug

# Watch for errors
kubectl logs -f -n kyverno deployment/kyverno | grep -i error

# Test expression offline
echo '{"test": "data"}' | kyverno jp query 'expression'
```

### Performance Issues

```bash
# Check policy evaluation time
kubectl get policyreport -o json | \
  jq '.items[].results[] | select(.processingTime > 100)'

# Add preconditions to skip unnecessary evaluations
# Use cached context variables
# Avoid expensive operations in loops
```

---

## Best Practices Checklist

- [ ] Test JMESPath expressions with `kyverno jp` before deploying
- [ ] Use audit mode first, then switch to enforce
- [ ] Provide defaults for optional fields (use `|| ''` or `|| \`0\``)
- [ ] Use backticks for literals (\`true\`, \`false\`, \`0\`)
- [ ] Validate with real Kubernetes resources
- [ ] Add preconditions for performance
- [ ] Provide helpful error messages with field values
- [ ] Test edge cases (null values, empty arrays, missing fields)
- [ ] Monitor policy reports after deployment
- [ ] Document complex expressions with comments

---

## Next Steps

- **[JMESPath Reference →](reference.md)** - Complete function reference
- **[Enterprise JMESPath Examples →](enterprise.md)** - Real-world policies
- **[JMESPath Advanced →](advanced.md)** - Advanced patterns
- **[JMESPath Patterns (Core) →](patterns.md)** - Core patterns
- **[Kyverno Templates Overview →](../kyverno/index.md)** - Complete template library
- **[Template Library Overview →](index.md)** - Back to main page
