---
title: Validation Patterns
description: >-
  Validate chaos experiments with SLI monitoring, incident detection testing, auto-remediation verification, and post-experiment analysis for reliability goals.
tags:
  - chaos-engineering
  - validation
  - sli
  - observability
---
# Validation Patterns

Chaos without validation is just breaking things. Validation transforms it into reliability engineering.

## SLI Monitoring During Chaos

Link chaos experiments to Service Level Indicators:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: chaos-with-validation
spec:
  entrypoint: chaos-test
  templates:
    - name: chaos-test
      steps:
        - - name: get-baseline
            template: query-slis
            arguments:
              parameters:
                - name: window
                  value: "5m"
        - - name: inject-chaos
            template: run-pod-deletion
        - - name: validate-during-chaos
            template: query-slis
            arguments:
              parameters:
                - name: window
                  value: "live"
        - - name: measure-recovery
            template: query-slis
            arguments:
              parameters:
                - name: window
                  value: "5m-post"
        - - name: analyze-results
            template: compare-slis
```

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

### Validation checklist

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

!!! tip "Test Your Monitoring"
    Chaos engineering is the only way to prove your alerts actually work. If the alert doesn't fire during chaos, it won't fire during a real incident.

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

## Related Documentation

- **[Back to Overview](index.md)** - Chaos engineering introduction
- **[Blast Radius Control](blast-radius.md)** - Safety and targeting
- **[Experiment Catalog](experiments.md)** - Ready-to-use scenarios
- **[Observability](observability.md)** - Metrics and alerting
