---
description: >-
  Control chaos engineering blast radius with namespace isolation, label scoping, time windows, progressive intensity scaling, and automatic rollback mechanisms.
tags:
  - chaos-engineering
  - blast-radius
  - safety
  - kubernetes
---

# Blast Radius Control

Uncontrolled chaos destroys production. Controlled chaos reveals fragility.

## Targeting Strategies

### Namespace Isolation

Run experiments in dedicated chaos namespaces:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  namespace: chaos-testing
  name: pod-deletion-staging
spec:
  action: pod-kill
  mode: fixed
  value: 1
  selector:
    namespaces:
      - staging
      - staging-services
    labelSelectors:
      app: api-gateway
```

### Label-Based Scoping

Tag experiments with blast radius constraints:

```yaml
selector:
  labelSelectors:
    app: worker
    chaos-target: "true"
    chaos-window: "business-hours-only"
```

### Time Windows

Restrict chaos to low-impact periods:

```yaml
schedule:
  cron: "0 2 * * 1-4"  # 2 AM, Monday-Thursday only
duration: 5m
```

### Progressive Intensity

Start small, escalate based on observability:

```yaml
# Day 1: Single pod, 30 seconds
mode: fixed
value: 1
duration: 30s

# Day 2: Two pods, 1 minute
mode: fixed
value: 2
duration: 1m

# Day 7: 25% during business hours
mode: percentage
value: 25
duration: 5m
```

!!! example "Real-World Progression"
    A SaaS company started chaos with 1 pod for 30 seconds in staging. After 2 weeks of validation, they progressed to 10% of production pods for 5 minutes. After 6 weeks, they ran continuous steady-state chaos at 5% intensity.

## Automatic Rollback

Configure automated rollback to prevent cascade failures:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-deletion-with-rollback
spec:
  action: pod-kill
  duration: "2m"
  selector:
    namespaces:
      - production
    labelSelectors:
      tier: web
  scheduling:
    # Auto-rollback if error rate exceeds threshold
    backoffBase: 1m
    maxAttempts: 3
```

Monitor error rates and auto-cancel:

```bash
# Example monitoring script
ERROR_RATE=$(curl -s prometheus:9090/api/v1/query \
  --data-urlencode 'query=rate(http_requests_total{status=~"5.."}[1m])' | \
  jq '.data.result[0].value[1] | tonumber')

if (( $(echo "$ERROR_RATE > 0.02" | bc -l) )); then
  kubectl delete podchaos -n chaos-testing pod-deletion-with-rollback
  echo "ROLLBACK: Error rate exceeded 2%"
fi
```

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

## Safety Checklist

Before running any experiment:

- [ ] Experiment documented with owner and rollback procedure
- [ ] On-call team notified of chaos window
- [ ] Blast radius validated (namespace, labels, pod count)
- [ ] Rollback tested in staging
- [ ] SLI dashboards visible and alert thresholds set
- [ ] No ongoing production incidents
- [ ] Low-traffic window selected
- [ ] Escalation path established

## Related Documentation

- **[Back to Overview](index.md)** - Chaos engineering introduction
- **[Validation Patterns](validation.md)** - SLI monitoring and testing
- **[Experiment Catalog](experiments.md)** - Ready-to-use scenarios
