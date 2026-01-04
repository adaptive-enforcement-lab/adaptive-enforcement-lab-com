---
title: Success Criteria Definition
description: >-
  Success criteria definition for chaos experiments. SLI-based validation, observable metrics, recovery verification, and validation timeline patterns.
tags:
  - chaos-engineering
  - sli
  - success-criteria
  - metrics
---
# Success Criteria Definition

Define concrete, measurable outcomes that prove your hypothesis.

!!! warning "Recovery Validation"
    Don't just validate during chaos. Verify that the system fully recovers after chaos ends. Incomplete recovery is a failed experiment.

## SLI-Based Success Criteria

Map success criteria to Service Level Indicators:

| SLI | Baseline | During Chaos | Success Threshold |
|-----|----------|--------------|-------------------|
| **Error Rate** | < 0.1% | < 0.5% | if < 2% |
| **P99 Latency** | 1.2s | 1.5s | if < 3s |
| **Availability** | 99.99% | 99.95% | if > 99.5% |
| **Recovery Time** | N/A | N/A | if < 30s |

## Observable Metrics

Define queries that validate success:

```promql
# Error rate stays acceptable
rate(http_requests_total{status=~"5.."}[1m]) < 0.005

# Latency remains bounded
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m])) < 1.5

# Replica count recovers
kube_deployment_status_replicas_available{deployment="api-gateway"} == 3

# Circuit breaker activates
circuit_breaker_state{dependency="database"} == 1  # OPEN
```

## Validation Timeline

Success criteria must consider timing:

```text
0-5s: Failure injected, initial impact
5-30s: System detects failure, activates fallback
30-120s: Degraded mode operation
120-180s: Chaos ends
180-240s: Full recovery
```

Define thresholds for each phase:

- **Detection**: Alert fires within 30s
- **Degradation**: Error rate < 5% during chaos
- **Recovery**: Full capacity within 60s after chaos ends

## Multi-Phase Validation

### Phase 1: Detection (0-30s)

Verify the system detects the failure:

- [ ] Health checks fail on affected pods
- [ ] Monitoring alerts fire
- [ ] Circuit breakers transition state
- [ ] Load balancers remove unhealthy targets

### Phase 2: Degradation (30s-chaos end)

Measure impact during chaos:

- [ ] Error rate within acceptable bounds
- [ ] Latency degradation controlled
- [ ] Fallback mechanisms activated
- [ ] User experience remains functional

### Phase 3: Recovery (chaos end + 60s)

Confirm full system recovery:

- [ ] All metrics return to baseline
- [ ] No lingering errors or retries
- [ ] Health checks pass
- [ ] Capacity restored to target

## Success Criteria Examples

### Example 1: Pod Deletion

**Hypothesis**: API gateway handles pod deletion gracefully

**Success Criteria**:

- Error rate remains < 0.5% during pod restart
- P99 latency increases < 50ms
- No requests fail for > 5 seconds
- Full capacity restored within 30s

**Validation Queries**:

```promql
# No sustained errors
rate(http_requests_total{status=~"5.."}[1m]) < 0.005

# Latency bounded
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[1m])) < 1.25

# Capacity restored
kube_deployment_status_replicas_available >= 3
```

### Example 2: Database Latency

**Hypothesis**: Circuit breaker protects app from slow database

**Success Criteria**:

- Circuit breaker opens within 5 failed requests
- Fallback cache activates automatically
- Error rate < 5% during degradation
- Normal operation resumes within 60s after DB recovers

**Validation Queries**:

```promql
# Circuit breaker opened
circuit_breaker_state{dependency="database"} == 1

# Cache hit rate increased
rate(cache_hits_total[1m]) / rate(cache_requests_total[1m]) > 0.8

# Errors controlled
rate(http_requests_total{status="503"}[1m]) < 0.05
```

### Example 3: Memory Pressure

**Hypothesis**: Application handles memory limits without OOM

**Success Criteria**:

- Pod remains responsive (health checks pass)
- Garbage collection triggers before limit
- Request queue depth bounded
- No pod restarts due to OOM

**Validation Queries**:

```promql
# Memory stays under limit
container_memory_usage_bytes / container_spec_memory_limit_bytes < 0.95

# GC activity increased
rate(gc_duration_seconds_count[1m]) > 0

# No OOM kills
kube_pod_container_status_restarts_total == 0
```

## Failure Conditions

Define what constitutes experiment failure:

### Hard Failures (Stop Immediately)

- Error rate exceeds 10%
- Complete service unavailability
- Data loss or corruption
- Security boundary violation

### Soft Failures (Flag for Review)

- Recovery takes longer than expected
- Alerts don't fire as expected
- Fallback mechanisms partially effective
- Performance degrades more than predicted

## Documentation Template

```yaml
success_criteria:
  error_rate:
    baseline: "< 0.1%"
    during_chaos: "< 0.5%"
    threshold: "< 2%"

  p99_latency:
    baseline: "1.2s"
    during_chaos: "1.5s"
    threshold: "< 3s"

  recovery_time:
    target: "< 30s"
    measured: "TBD"

  availability:
    target: "> 99.5%"
    measured: "TBD"
```

## Related Topics

- **[Hypothesis Formation](hypothesis.md)** - Define what you're testing
- **[SLI Monitoring](sli-monitoring.md)** - Track metrics during chaos
- **[Validation Patterns](validation.md)** - Verify experiment outcomes

---

*Success criteria transform vague resilience goals into measurable validation. If you can't define success, you can't declare victory.*
