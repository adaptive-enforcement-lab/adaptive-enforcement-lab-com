---
description: >-
  SLI monitoring during chaos experiments. Baseline measurement, live tracking, recovery validation, and metric comparison patterns.
tags:
  - chaos-engineering
  - sli
  - monitoring
  - metrics
---

# SLI Monitoring During Chaos

Link chaos experiments to Service Level Indicators for measurable validation.

!!! success "SLI Validation Checklist"
    - [ ] Baseline metrics captured before chaos
    - [ ] Live metrics tracked during chaos
    - [ ] Recovery metrics measured after chaos
    - [ ] Comparison shows system returned to baseline
    - [ ] No degradation persists after experiment ends

## Baseline Measurement

Capture pre-chaos metrics:

```yaml
- name: get-baseline
  template: query-slis
  arguments:
    parameters:
      - name: window
        value: "5m"
      - name: metrics
        value: "error_rate,p99_latency,availability"
```

Example baseline query:

```promql
# Baseline error rate
avg_over_time(
  rate(http_requests_total{status=~"5.."}[1m])[5m:]
)
```

## Live Monitoring

Track metrics during chaos injection:

```yaml
- name: validate-during-chaos
  template: query-slis
  arguments:
    parameters:
      - name: window
        value: "live"
      - name: comparison
        value: "baseline"
```

Alert if metrics exceed thresholds:

```promql
# Alert on excessive error rate
(
  rate(http_requests_total{status=~"5.."}[1m]) > 0.02
) and (
  chaos_experiment_active == 1
)
```

## Recovery Validation

Measure post-chaos recovery:

```yaml
- name: measure-recovery
  template: query-slis
  arguments:
    parameters:
      - name: window
        value: "5m-post"
      - name: baseline
        value: "{{ steps.get-baseline.outputs.metrics }}"
```

Verify metrics return to baseline:

```promql
# Recovery check: error rate back to baseline
abs(
  rate(http_requests_total{status=~"5.."}[1m])
  - baseline_error_rate
) < 0.001
```

## Key Metrics to Track

### Service Level Indicators

| Metric | Query | Threshold |
|--------|-------|-----------|
| **Error Rate** | `rate(http_requests_total{status=~"5.."}[1m])` | < 0.5% during chaos |
| **P99 Latency** | `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m]))` | < 2× baseline |
| **Availability** | `avg_over_time(up[5m])` | > 99.5% |
| **Throughput** | `rate(http_requests_total[1m])` | > 80% baseline |

### Infrastructure Metrics

| Metric | Query | Purpose |
|--------|-------|---------|
| **Pod Restarts** | `kube_pod_container_status_restarts_total` | Detect crash loops |
| **CPU Usage** | `rate(container_cpu_usage_seconds_total[1m])` | Resource saturation |
| **Memory Usage** | `container_memory_usage_bytes` | Memory leaks or pressure |
| **Network Errors** | `rate(node_network_receive_errs_total[1m])` | Network degradation |

## Monitoring Workflow

### Pre-Chaos (T-5m to T0)

1. Query baseline metrics
2. Store results for comparison
3. Verify metrics are stable
4. Confirm no ongoing incidents

```bash
# Capture baseline
BASELINE_ERROR_RATE=$(promtool query instant \
  'rate(http_requests_total{status=~"5.."}[1m])' \
  --time=$(date -u +%s))

echo "Baseline error rate: $BASELINE_ERROR_RATE"
```

### During Chaos (T0 to T+duration)

1. Track live metrics every 10s
2. Compare to baseline thresholds
3. Alert if thresholds exceeded
4. Trigger rollback if critical

```bash
# Monitor during chaos
while chaos_active; do
  ERROR_RATE=$(promtool query instant \
    'rate(http_requests_total{status=~"5.."}[1m])')

  if [ "$ERROR_RATE" > 0.02 ]; then
    echo "ALERT: Error rate exceeded threshold"
    trigger_rollback
  fi

  sleep 10
done
```

### Post-Chaos (T+duration to T+duration+5m)

1. Measure recovery metrics
2. Compare to baseline
3. Verify full recovery
4. Document results

```bash
# Verify recovery
RECOVERY_ERROR_RATE=$(promtool query instant \
  'rate(http_requests_total{status=~"5.."}[1m])' \
  --time=$(date -u +%s))

if [ "$RECOVERY_ERROR_RATE" == "$BASELINE_ERROR_RATE" ]; then
  echo "SUCCESS: System recovered to baseline"
else
  echo "WARNING: System has not fully recovered"
fi
```

## Metric Collection Patterns

### Pattern 1: Prometheus Queries

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: chaos-queries
data:
  error-rate.prom: |
    rate(http_requests_total{status=~"5.."}[1m])

  p99-latency.prom: |
    histogram_quantile(0.99,
      rate(http_request_duration_seconds_bucket[1m]))

  availability.prom: |
    avg_over_time(up{job="api-server"}[5m])
```

### Pattern 2: Grafana Dashboard

Create a dedicated chaos experiment dashboard:

- **Panel 1**: Error rate (baseline vs. current)
- **Panel 2**: Latency percentiles (P50, P95, P99)
- **Panel 3**: Throughput (requests/second)
- **Panel 4**: Infrastructure metrics (CPU, memory, restarts)

### Pattern 3: Alerting Rules

```yaml
groups:
  - name: chaos-monitoring
    interval: 10s
    rules:
      - alert: ChaosErrorRateExceeded
        expr: |
          rate(http_requests_total{status=~"5.."}[1m]) > 0.02
          and chaos_experiment_active == 1
        for: 30s
        annotations:
          summary: "Chaos experiment causing excessive errors"
```

## Related Topics

- **[Success Criteria](success-criteria.md)** - Define metric thresholds
- **[Validation Patterns](validation.md)** - Verify experiment outcomes
- **[Observability](../observability.md)** - Complete monitoring setup

---

*Metrics are the language of chaos engineering. Without measurement, chaos is just noise.*
