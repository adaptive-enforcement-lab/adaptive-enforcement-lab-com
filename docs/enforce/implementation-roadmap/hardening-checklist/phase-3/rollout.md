---
description: >-
  Policy rollout strategy for runtime enforcement. Audit-first approach, violation monitoring, phased enforcement, and metrics tracking for safe Kyverno deployment.
tags:
  - rollout
  - audit
  - deployment
  - monitoring
  - kyverno
---

# Phase 3: Policy Rollout Strategy

Deploy policies safely with audit-first approach.

!!! warning "Audit Before Enforce"
    Always deploy policies in Audit mode first. Monitor violations for 1 week. Fix violations. Then switch to Enforce mode.

---

## Rollout Phases

### Week 1: Audit Mode

```yaml
spec:
  validationFailureAction: Audit  # Log violations, don't block
```

Monitor violations:

```bash
kubectl get policyreport -A
kubectl describe policyreport -n production
```

---

### Week 2: Fix Violations

Address all policy violations identified in Week 1:

```bash
# Example: Add resource limits to all deployments
kubectl set resources deployment nginx -n production \
  --limits=cpu=200m,memory=512Mi \
  --requests=cpu=100m,memory=256Mi
```

---

### Week 3: Enforce Mode

```yaml
spec:
  validationFailureAction: Enforce  # Block non-compliant resources
```

Verify enforcement:

```bash
# Attempt to deploy non-compliant pod (should be blocked)
kubectl apply -f non-compliant-pod.yaml
```

---

### Week 4: Monitor and Tune

Track policy effectiveness:

```bash
# Check policy reports
kubectl get clusterpolicyreport -o wide

# Export metrics for dashboard
kubectl get policyreport -A -o json | \
  jq '[.items[] | {namespace: .metadata.namespace, pass: .summary.pass, fail: .summary.fail}]'
```

---

## Metrics to Track

**Policy Enforcement**:

- Number of pods blocked by resource limit policy
- Number of pods blocked by image source policy
- Number of pods blocked by security context policy
- Policy violation rate by namespace

**Compliance Posture**:

- Percentage of pods with resource limits
- Percentage of images from approved registries
- Percentage of pods with secure security context
- Policy Reporter pass/fail ratio

!!! success "Target Metrics"
    - Resource limits: 100% of pods
    - Approved registries: 100% of images
    - Secure context: 100% of pods
    - Policy violation rate: < 1% after enforcement

---

## Related Patterns

- **[Policy Enforcement](policy-enforcement.md)** - Core runtime policies
- **[Advanced Policies](advanced-policies.md)** - Extended controls
- **[Phase 3 Overview →](index.md)** - Runtime phase summary

---

*Audit mode deployed. Violations fixed. Enforce mode enabled. Metrics tracked. Rollout complete.*
