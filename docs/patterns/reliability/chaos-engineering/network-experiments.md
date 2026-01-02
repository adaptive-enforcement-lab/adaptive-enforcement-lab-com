---
description: >-
  Network chaos experiments. Latency injection and dependency timeout testing with circuit breaker validation and recovery procedures.
tags:
  - chaos-engineering
  - network-chaos
  - kubernetes
  - experiments
---

# Network Chaos Experiments

Network latency injection and dependency timeout testing to validate circuit breakers and fallback patterns.

!!! warning "Timeouts Are Configuration, Not Code"
    Most timeout bugs come from misconfiguration, not logic errors. Chaos experiments expose bad timeout values before they cause customer impact.

---

## Experiment 2: Network Latency (Dependency Timeout Testing)

**Purpose**: Verify that upstream services handle slow dependencies gracefully with timeouts and circuit breakers.

**Setup**: Database-backed service with configured connection timeouts.

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  namespace: chaos-testing
  name: db-latency-injection
spec:
  action: delay
  delay:
    latency: "500ms"
    jitter: "100ms"
  target:
    selector:
      namespaces:
        - production
      podSelector:
        matchLabels:
          app: postgres
  source:
    selector:
      namespaces:
        - production
      podSelector:
        matchLabels:
          tier: application
  mode: all
  duration: 5m
  scheduling:
    cron: "0 3 * * 3"
```

### Expected behavior

1. **0-5s**: Database queries begin timing out
2. **5-15s**: Application circuit breaker opens (after N failures)
3. **15-30s**: Requests either fail fast or fall back to cache
4. **30-300s**: Degraded mode operation with fallback responses
5. **300s+**: Latency injection stops, recovery to normal operation

### Success criteria

- Application respects 2-second query timeout (fails instead of hanging)
- Circuit breaker opens after 5 consecutive failures
- Cache hits increase to 80%+ during high latency period
- P50 latency stays under 500ms (application-level timeout)
- Error rate increases but remains acceptable (< 5% client errors)
- Recovery to normal operation completes within 2 minutes

### Validation queries

```promql
# Database query timeouts
increase(pg_client_errors_total{error_type="timeout"}[5m])

# Circuit breaker state
circuit_breaker_state{service="db-client"} == 1  # 1 = OPEN

# Cache hit rate increase
increase(cache_hits_total[5m]) / increase(cache_requests_total[5m]) > 0.8

# Acceptable error rate during chaos
increase(http_requests_total{status="500"}[5m]) / increase(http_requests_total[5m]) < 0.05

# Request latency remains bounded
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m])) < 0.5
```

### Rollback procedure

```bash
# Remove network chaos
kubectl delete networkchaos -n chaos-testing db-latency-injection

# Verify database connectivity restored
kubectl exec -n production deployment/app -- \
  pg_isready -h postgres.production.svc.cluster.local

# Check circuit breaker resets
kubectl logs -n production deployment/app | grep "circuit.*closed"

# Monitor recovery metrics
kubectl port-forward -n production svc/app 8080:8080
# Visit http://localhost:8080/metrics | grep circuit_breaker
```

---

## Related Documentation

- **[Pod Experiments →](pod-experiments.md)** - Pod deletion and crash loop testing
- **[Resource Experiments →](resource-experiments.md)** - Memory and CPU pressure testing
- **[Dependency Experiments →](dependency-experiments.md)** - Multi-service resilience testing
- **[Back to Overview](index.md)** - Chaos engineering introduction
