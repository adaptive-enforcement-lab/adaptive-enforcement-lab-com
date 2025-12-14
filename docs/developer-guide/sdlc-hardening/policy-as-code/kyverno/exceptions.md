---
title: Kyverno Testing Exception Management
description: >-
  Exception management strategies, PolicyException resource usage,
  common pitfalls, and debugging policy failures.
---

# Kyverno Testing Exception Management

## Exception Management

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

Not every rule applies everywhere:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-resource-limits
      match:
        any:
          - resources:
              kinds:
                - Deployment
      exclude:
        any:
          - resources:
              namespaces:
                - kube-system
                - monitoring
      validate:
        message: "Resource limits required"
        pattern:
          spec:
            template:
              spec:
                containers:
                  - resources:
                      limits:
                        memory: "?*"
```

System namespaces excluded. Application namespaces enforced.

### Namespace-Based Exclusions

```yaml
exclude:
  any:
    - resources:
        namespaces:
          - kube-system
          - kube-public
          - kube-node-lease
```

### Label-Based Exclusions

```yaml
exclude:
  any:
    - resources:
        selector:
          matchLabels:
            policy-exception: "true"
```

### Resource-Specific Exclusions

```yaml
exclude:
  any:
    - resources:
        names:
          - coredns
          - metrics-server
        namespaces:
          - kube-system
```

---

## PolicyException Resource

Kyverno 1.10+ supports explicit exceptions:

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: allow-privileged-monitoring
  namespace: monitoring
spec:
  exceptions:
    - policyName: restrict-privilege-escalation
      ruleNames:
        - deny-privilege-escalation
  match:
    any:
      - resources:
          kinds:
            - Pod
          namespaces:
            - monitoring
          names:
            - prometheus-*
```

**Benefits:**

- Auditable exceptions
- Separate from policy definition
- Can be reviewed/expired independently

---

## Common Pitfalls

### Pitfall 1: Policy Applied to Wrong Resources

**Problem:** Policy matches unintended resources.

```yaml
# BAD: Matches ALL resources
match:
  any:
    - resources:
        kinds:
          - "*"

# GOOD: Specific resource types
match:
  any:
    - resources:
        kinds:
          - Deployment
          - StatefulSet
```

### Pitfall 2: Wildcard Patterns Too Broad

**Problem:** Pattern matches more than intended.

```yaml
# BAD: Matches any gcr.io image
image: "gcr.io/*"

# GOOD: Matches specific project
image: "gcr.io/my-project/*"
```

### Pitfall 3: Missing Background Scans

**Problem:** Existing resources bypass policy.

```yaml
spec:
  background: true  # Apply to existing resources, not just new
```

### Pitfall 4: No Audit Period

**Problem:** Enforcing immediately breaks production.

**Fix:** Always start with audit mode:

```yaml
spec:
  validationFailureAction: Audit  # First
# ... fix violations ...
spec:
  validationFailureAction: Enforce  # Then
```

---

## Debugging Policy Failures

### Check PolicyReports

```bash
# View policy violations
kubectl get policyreport -A

# Detailed report
kubectl get policyreport polr-ns-default -o yaml
```

### Check Kyverno Logs

```bash
# Admission controller logs
kubectl logs -n kyverno deployment/kyverno -f

# Look for webhook failures
kubectl logs -n kyverno deployment/kyverno | grep -i "denied"
```

### Test Policy Locally

```bash
# Reproduce failure locally
kyverno apply policy.yaml --resource failing-manifest.yaml -v 4
```

### Validate Policy Syntax

```bash
# Check policy is valid
kyverno apply policy.yaml --validate
```

---

## Policy Report Example

```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: polr-ns-production
  namespace: production
results:
  - policy: require-resource-limits
    rule: check-resource-limits
    resources:
      - kind: Deployment
        name: api
        namespace: production
    result: fail
    message: "Resource limits are required for all containers"
    scored: true
```

---

## Related Guides

- **[Kyverno Basics](index.md)** for Installation and policy structure
- **[Policy Patterns](policy-patterns.md)** for Common validation patterns
- **[CI/CD Integration](ci-cd-integration.md)** for Automated testing in pipelines

---

*Policy tested locally. Valid manifests passed. Invalid manifests failed. Exceptions documented. CI validated changes. Policy deployed to audit mode. Violations fixed. Policy switched to enforce. Zero production incidents.*
