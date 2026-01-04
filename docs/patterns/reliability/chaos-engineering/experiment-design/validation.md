---
title: Validation Patterns
description: >-
  Validation patterns for chaos experiments. Incident detection testing, auto-remediation verification, experiment catalog template, and pre-experiment checklist.
tags:
  - chaos-engineering
  - validation
  - testing
  - runbooks
---
# Validation Patterns

Transform observations into actionable reliability improvements.

!!! tip "Test Your Monitoring"
    Chaos engineering is the only way to prove your alerts actually work. If the alert doesn't fire during chaos, it won't fire during a real incident.

## Incident Detection Testing

Verify your alerting actually fires when you break things:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: latency-alert-validation
spec:
  action: delay
  delay:
    latency: "500ms"
    jitter: "100ms"
  selector:
    namespaces:
      - staging
    labelSelectors:
      app: payment-processor
  duration: 5m
  scheduling:
    cron: "0 3 * * 2"  # Tuesday 3 AM
```

Validation checklist:

- [ ] P99 latency alert fires within 30 seconds
- [ ] Error rate alert triggers before customer impact
- [ ] On-call receives notification
- [ ] Slack channel posts alert context
- [ ] Runbook link loads correctly
- [ ] Dashboard drilldown shows affected pods

## Auto-Remediation Testing

Validate that your self-healing actually works:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: test-auto-remediation
spec:
  entrypoint: remediation-test
  templates:
    - name: remediation-test
      steps:
        - - name: baseline-check
            template: health-check
        - - name: inject-fault
            template: kill-replica
        - - name: wait-for-recovery
            template: wait
            arguments:
              parameters:
                - name: duration
                  value: "30s"
        - - name: validate-recovery
            template: health-check
        - - name: assess
            template: compare-metrics
```

Expected outcomes:

- [ ] Kubernetes detects pod failure within 10s
- [ ] New pod schedules within 20s
- [ ] Readiness probe succeeds within 30s
- [ ] Traffic redirects to new pod automatically
- [ ] No manual intervention required

## Experiment Catalog Template

Document every experiment with this structure:

```yaml
experiment:
  name: pod-deletion-api-gateway
  date: 2024-01-10
  duration: 2m
  blast_radius: 1/3 replicas

hypothesis:
  given: "API gateway with 3 replicas and load balancer"
  when: "One pod is killed"
  then: "Traffic redirects to remaining replicas within 5 seconds"
  and: "Error rate < 0.5%, P99 latency < 1.5s"

success_criteria:
  error_rate: "< 0.5%"
  p99_latency: "< 1.5s"
  recovery_time: "< 30s"
  availability: "> 99.95%"

results:
  sli_impact:
    error_rate_max: 0.3%
    p99_latency_max: 1.2s
    availability: 99.97%
    recovery_time: 18s

  observations:
    - Readiness probe takes 8s (tuned from 10s)
    - Circuit breaker needed lower failure threshold (5 → 3)
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

## Pre-Experiment Checklist

Before running any chaos experiment:

- [ ] Experiment documented in runbook with owner and contact
- [ ] On-call team notified of chaos window
- [ ] Blast radius explicitly validated (namespace, labels, count)
- [ ] Rollback procedure tested in staging
- [ ] SLI dashboards visible and alert thresholds set
- [ ] No ongoing production incidents
- [ ] Low-traffic window selected (off-peak if production)
- [ ] Escalation path established (who can stop experiment if needed)

## Validation Workflow

### 1. Pre-Chaos Validation

```bash
# Verify system health
kubectl get pods -n production
kubectl get deployments -n production

# Check recent errors
curl -s prometheus:9090/api/v1/query \
  --data-urlencode 'query=rate(http_requests_total{status=~"5.."}[5m])'

# Confirm no active incidents
curl -s pagerduty-api/incidents?status=triggered
```

### 2. During-Chaos Validation

```bash
# Monitor error rate
watch -n 5 'curl -s prometheus:9090/api/v1/query \
  --data-urlencode "query=rate(http_requests_total{status=~\"5..\"}[1m])"'

# Track pod status
kubectl get pods -n production -w

# Watch alerts
kubectl logs -n monitoring -l app=alertmanager -f
```

### 3. Post-Chaos Validation

```bash
# Verify recovery
kubectl get pods -n production
kubectl get deployments -n production

# Check metrics returned to baseline
curl -s prometheus:9090/api/v1/query \
  --data-urlencode 'query=rate(http_requests_total{status=~"5.."}[5m])'

# Review incident timeline
kubectl logs -n monitoring -l app=alertmanager --since=10m
```

## Validation Patterns by Type

### Pattern: Health Check Validation

Verify health endpoints respond correctly:

```yaml
- name: health-check
  script:
    image: curlimages/curl
    command: [sh]
    source: |
      STATUS=$(curl -s -o /dev/null -w '%{http_code}' http://api-gateway/health)
      if [ "$STATUS" != "200" ]; then
        echo "Health check failed: $STATUS"
        exit 1
      fi
      echo "Health check passed"
```

### Pattern: Metric Validation

Compare current metrics to baseline:

```yaml
- name: compare-metrics
  script:
    image: prom/prometheus
    command: [sh]
    source: |
      BASELINE={{inputs.parameters.baseline}}
      CURRENT=$(promtool query instant 'rate(http_requests_total{status=~"5.."}[1m])')

      if [ "$CURRENT" -gt "$BASELINE" ]; then
        echo "ERROR: Metrics degraded"
        exit 1
      fi
      echo "SUCCESS: Metrics within baseline"
```

### Pattern: Alert Validation

Confirm alerts fired as expected:

```yaml
- name: validate-alerts
  script:
    image: curlimages/curl
    command: [sh]
    source: |
      ALERTS=$(curl -s alertmanager:9093/api/v1/alerts | jq '.data | length')

      if [ "$ALERTS" -eq 0 ]; then
        echo "ERROR: No alerts fired during chaos"
        exit 1
      fi
      echo "SUCCESS: Alerts fired as expected"
```

## Related Topics

- **[Hypothesis Formation](hypothesis.md)** - Define what to validate
- **[Success Criteria](success-criteria.md)** - Set validation thresholds
- **[SLI Monitoring](sli-monitoring.md)** - Track validation metrics
- **[Experiment Design Overview](index.md)** - Complete methodology

---

*Validation turns chaos into learning. Without validation, you're just breaking things and hoping for the best.*
