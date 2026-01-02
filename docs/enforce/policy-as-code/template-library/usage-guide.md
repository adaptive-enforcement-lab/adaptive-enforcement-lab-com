---
description: >-
  Policy template customization guide. Workflow for adapting templates, validation best practices, common customization patterns, and troubleshooting for Kyverno and OPA policies.
tags:
  - policy-as-code
  - customization
  - troubleshooting
  - best-practices
---

# Policy Template Usage Guide

Complete guide to customizing, validating, and troubleshooting policy templates. Step-by-step workflow from download to production deployment.

---

## Customization Workflow

!!! tip "Test in Isolation First"
    Never deploy policies directly to production. Test in a dedicated namespace with sample workloads. Validate behavior in `audit` mode for 48 hours minimum before enforcing.

### Step 1: Download Template

```bash
curl -O https://example.com/templates/pod-security.yaml
```

### Step 2: Review Defaults

```bash
kyverno apply pod-security.yaml --dry-run
```

### Step 3: Customize for Your Environment

```yaml
# Edit variables section
metadata:
  annotations:
    registry: registry.example.com
    approved-teams: platform,security
```

### Step 4: Test in Audit Mode

```bash
sed -i 's/enforce/audit/' pod-security.yaml
kubectl apply -f pod-security.yaml
```

### Step 5: Monitor Violations

```bash
kubectl logs -n kyverno -f deployment/kyverno
```

### Step 6: Switch to Enforcement

```bash
sed -i 's/audit/enforce/' pod-security.yaml
kubectl apply -f pod-security.yaml
```

---

## Validation Best Practices

| Step | Command | Purpose |
|------|---------|---------|
| **Syntax Check** | `kubectl apply --dry-run=client -f policy.yaml` | Validate YAML |
| **Policy Lint** | `kyverno apply --dry-run` | Check policy logic |
| **Live Test** | Apply to test namespace with `audit` mode | Identify real violations |
| **Audit Review** | `kubectl logs -n kyverno deployment/kyverno` | Monitor before enforcement |
| **Staged Rollout** | Apply to namespace subset first | Gradual enforcement |

---

## Common Customization Patterns

### Exclude System Namespaces

```yaml
exclude:
  resources:
    namespaces:
      - kube-system
      - kube-public
      - kube-node-lease
```

### Exclude Specific Workloads

```yaml
exclude:
  resources:
    selector:
      matchLabels:
        skip-policies: "true"
```

### Condition-Based Rules

```yaml
validate:
  pattern:
    metadata:
      labels:
        security-level: "?*"
```

### Multi-Rule Policies

```yaml
rules:
  - name: rule-1
    match:
      resources:
        kinds:
          - Deployment
  - name: rule-2
    match:
      resources:
        kinds:
          - Pod
```

---

## Troubleshooting

!!! warning "Common Mistake: Wrong Mode"
    If you see violations in logs but deployments succeed, you're in `audit` mode. Change `validationFailureAction: audit` to `validationFailureAction: enforce`.

### Policy Not Triggering

**Problem**: Policy applied but violations not appearing

**Solutions**:

1. Check `validationFailureAction: audit` (change to `enforce` if testing in audit mode)
2. Verify `background: true` to apply to existing resources
3. Confirm pod matches `match` selectors: `kubectl describe pod <name>`
4. Check policy logs: `kubectl logs -n kyverno deployment/kyverno`

### False Positives

**Problem**: Policy blocking legitimate workloads

**Solutions**:

1. Add workload to `exclude` rules
2. Use label selectors to target specific deployments
3. Adjust pattern to be less restrictive
4. Run in `audit` mode temporarily while refining

### Performance Issues

**Problem**: Kyverno slowing down cluster operations

**Solutions**:

1. Use `background: false` to skip existing resource validation
2. Limit policy scope with namespace selectors
3. Optimize pattern matching (avoid wildcards when possible)
4. Monitor Kyverno resource usage: `kubectl top pod -n kyverno`

---

## Related Resources

- **[Kyverno Templates →](kyverno-templates.md)** - Pod security, images, resources
- **[OPA Templates →](opa-templates.md)** - Network policies, constraints
- **[CI/CD Integration →](ci-cd-integration.md)** - Automated validation
- **[Template Library Overview →](index.md)** - Back to main page

---

## External References

- [Kyverno Best Practices](https://kyverno.io/docs/writing-policies/best-practices/)
- [OPA/Gatekeeper Documentation](https://open-policy-agent.org/docs/latest/kubernetes-admission-control/)
- [Kyverno Community](https://kyverno.io/community/)
- [Policy Testing Pipeline](https://kyverno.io/docs/testing-policies/)
