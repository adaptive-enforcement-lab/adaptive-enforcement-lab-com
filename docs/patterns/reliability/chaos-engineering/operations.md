---
description: >-
  Running chaos experiments safely. Pre-experiment checklist, execution best practices, monitoring, and common pitfalls.
tags:
  - chaos-engineering
  - operations
  - safety
  - best-practices
---

# Running Experiments Safely

## Pre-Experiment Checklist

!!! warning "Never Run Chaos During Incidents"
    If there's an active production incident, postpone chaos experiments. Chaos creates controlled failure. Uncontrolled failure plus controlled failure equals chaos you can't debug.

- [ ] Experiment documented in runbook with owner and contact
- [ ] On-call team notified of chaos window
- [ ] Blast radius explicitly validated (namespace, labels, count)
- [ ] Rollback procedure tested in staging
- [ ] SLI dashboards visible and alert thresholds set
- [ ] No ongoing production incidents
- [ ] Low-traffic window selected (off-peak if production)
- [ ] Escalation path established (who can stop experiment if needed)

## Execution Best Practices

### Start small

```bash
# Test in staging first
mode: fixed
value: 1
duration: 30s

# Only move to production after staging validation
mode: percentage
value: 10
duration: 5m
```

### Observe continuously

```bash
# Open observability dashboard before starting
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090 with key queries pre-loaded

# Open logs aggregator
kubectl port-forward -n logging svc/loki 3100:3100

# Monitor chaos status live
watch kubectl get podchaos,networkchaos -n chaos-testing
```

### Stop at the first sign of trouble

```bash
# If alert fires unexpectedly, delete chaos resource immediately
kubectl delete podchaos -n chaos-testing <name>

# Verify rollback worked
kubectl get pods -n production
# Expected: All replicas running and ready
```

## Post-Experiment Analysis

After each experiment, document findings:

```yaml
experiment:
  name: pod-deletion-api-gateway
  date: 2024-01-10
  duration: 2m
  blast_radius: 1/3 replicas

results:
  sli_impact:
    error_rate_max: 0.3%  # < 0.5% threshold
    p99_latency_max: 1.2s # < 1.5s threshold
    availability: 99.97%

  discoveries:
    - Readiness probe takes 8s (tuned from 10s)
    - Circuit breaker needed lower failure threshold (5 -> 3)
    - Cache hit rate improved during degradation

  action_items:
    - Investigate readiness probe slowness (DB dependency?)
    - Review circuit breaker timeout configuration
    - Document fallback responses for team

  next_steps:
    - Increase blast radius to 2 replicas
    - Extend duration to 5m
    - Combine with network chaos
```

## Common Pitfalls and Solutions

!!! tip "Use Explicit Labels for Targeting"
    Don't rely on generic labels like `app: api`. Add a `chaos-target: "true"` label to specific pods. This prevents accidental blast radius expansion.

### Pitfall 1: Blast radius grows during experiment

**Problem**: You start with 1 pod but 3 die.

**Solution**: Always specify exact selectors and test in staging first:

```yaml
# BAD: Label selector too broad
selector:
  labelSelectors:
    app: api

# GOOD: Specific labels with chaos targeting
selector:
  labelSelectors:
    app: api-gateway
    tier: web
    chaos-target: "true"
  namespaces:
    - chaos-testing
```

### Pitfall 2: Experiment never rolls back

**Problem**: Chaos resource still exists after duration, affecting new pods.

**Solution**: Use TTL and explicit cleanup:

```yaml
spec:
  duration: 5m
  # Add safeguard
  schedule:
    cron: "*/5 * * * *"
    duration: 5m
```

### Pitfall 3: Alerts don't fire during chaos

**Problem**: Your alert rules are missing the chaos scenario.

**Solution**: Test alert conditions in chaos experiments:

```promql
# Wrong: Triggers on any error
alert: HighErrorRate
expr: rate(errors_total[5m]) > 0.01

# Better: Accounts for graceful degradation
alert: UnacceptableErrorRate
expr: rate(errors_total{error_type!="graceful_degradation"}[5m]) > 0.01
```

### Pitfall 4: Recovery validation never runs

**Problem**: Experiment ends but you don't check if system recovered.

**Solution**: Add validation step to workflow:

```yaml
- - name: stop-chaos
    template: remove-chaos
- - name: wait-for-recovery
    template: wait
    arguments:
      parameters:
        - name: duration
          value: "30s"
- - name: validate-recovery
    template: check-all-replicas-ready
```

## Related Documentation

- **[Back to Overview](index.md)** - Chaos engineering introduction
- **[Validation Patterns](validation.md)** - SLI monitoring and testing
- **[Observability](observability.md)** - Metrics and alerting
