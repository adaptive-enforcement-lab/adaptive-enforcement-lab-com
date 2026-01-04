---
title: Observability Patterns
description: >-
  Instrument chaos experiments with Prometheus metrics, Grafana dashboards, circuit breaker state tracking, and alert rules for validating resilience patterns.
tags:
  - chaos-engineering
  - observability
  - metrics
  - prometheus
---
# Observability Patterns

## Key Metrics to Instrument

!!! tip "Track Chaos Experiment State"
    Add a metric for active chaos experiments. This appears in dashboards and alerts. When debugging a 3am incident, you need to know if chaos is running.

```python
# Application-level circuit breaker state
circuit_breaker_state = Gauge(
    'circuit_breaker_state',
    'Circuit breaker state (0=closed, 1=open, 2=half-open)',
    labelnames=['service', 'dependency']
)

# Fallback activation
fallback_activated = Counter(
    'fallback_activated_total',
    'Total times fallback logic was activated',
    labelnames=['feature', 'reason']
)

# Graceful degradation level
degradation_level = Gauge(
    'degradation_level',
    'Current degradation level (0=full, 1=partial, 2=fallback)',
    labelnames=['service']
)

# Recovery time after failure
recovery_time_seconds = Histogram(
    'recovery_time_seconds',
    'Time to recover from failure injection',
    labelnames=['failure_type']
)
```

## Alert Rules for Chaos Validation

```yaml
groups:
  - name: chaos_validation
    interval: 30s
    rules:
      - alert: UnexpectedErrorRateDuringChaos
        expr: |
          (rate(http_requests_total{status=~"5.."}[1m]) > 0.02)
          and
          (chaos_experiment_active == 1)
        for: 1m
        labels:
          severity: critical
          component: observability
        annotations:
          summary: "Error rate exceeded threshold during chaos experiment"

      - alert: CircuitBreakerDidNotOpen
        expr: |
          (increase(external_api_errors_total[5m]) > 10)
          and
          (circuit_breaker_state == 0)
        for: 30s
        labels:
          severity: warning
          component: reliability
        annotations:
          summary: "Circuit breaker should have opened but didn't"
```

## Monitoring Integration

### Prometheus Queries

```promql
# Error rate during chaos
rate(http_requests_total{status=~"5.."}[1m])

# Latency impact
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m]))

# Pod replacement time
min(time() - pod_created_timestamp_seconds) by (pod)

# Circuit breaker state
circuit_breaker_state{service="api"}

# Cache hit rate during degradation
increase(cache_hits_total[5m]) / increase(cache_requests_total[5m])
```

### Grafana Dashboards

Key panels to track during chaos:

1. **Error Rate Timeline** - Shows spike during chaos injection
2. **Latency Percentiles** - P50, P95, P99 over experiment duration
3. **Pod Status** - Running, pending, failed pods
4. **Circuit Breaker State** - Open/closed/half-open timeline
5. **Recovery Metrics** - Time to baseline after chaos ends

## Chaos Experiment Tracking

Mark experiment windows in metrics:

```python
# Set experiment active flag
chaos_experiment_active.set(1)

# Record experiment metadata
chaos_experiment_info.labels(
    name="pod-deletion",
    blast_radius="1/3",
    namespace="production"
).set(1)

# At completion
chaos_experiment_active.set(0)
chaos_experiment_duration.observe(experiment_duration_seconds)
```

## Related Documentation

- **[Back to Overview](index.md)** - Chaos engineering introduction
- **[Validation Patterns](validation.md)** - SLI monitoring and testing
- **[Operations](operations.md)** - Running experiments safely
