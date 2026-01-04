---
title: Retry Strategies
description: >-
  Recover from transient failures automatically with retry strategies. Configure exponential backoff, jitter, and trigger-level retries for reliable event flow.
---
# Retry Strategies

Transient failures like network timeouts, temporary service unavailability, and rate limits are common in distributed systems. Retry strategies automatically recover from these failures without manual intervention. For the complete reference, see the [official Trigger Retry docs](https://argoproj.github.io/argo-events/sensors/triggers/intro/#policy).

---

## Retry Configuration

Add retry behavior to any trigger:

```yaml
triggers:
  - template:
      name: api-call
      http:
        url: https://api.example.com/webhook
        method: POST
    retryStrategy:
      steps: 5
      duration: 5s
      factor: 2
      jitter: 0.2
```

**Retry parameters:**

| Field | Purpose | Example |
| ------- | --------- | --------- |
| `steps` | Maximum retry attempts | `5` |
| `duration` | Initial delay between retries | `5s` |
| `factor` | Multiplier for exponential backoff | `2` |
| `jitter` | Random variation (0-1) to prevent thundering herd | `0.2` |

---

## Exponential Backoff

With the configuration above, retry timing follows this pattern:

| Attempt | Base Delay | With Jitter (±20%) |
| --------- | ------------ | ------------------- |
| 1 | 5s | 4-6s |
| 2 | 10s | 8-12s |
| 3 | 20s | 16-24s |
| 4 | 40s | 32-48s |
| 5 | 80s | 64-96s |

Total maximum wait: ~3 minutes before giving up.

---

## Workflow Trigger Retry

For Argo Workflow triggers, configure retry at both levels:

```yaml
triggers:
  - template:
      name: deploy
      argoWorkflow:
        operation: submit
        source:
          resource:
            apiVersion: argoproj.io/v1alpha1
            kind: Workflow
            spec:
              templates:
                - name: main
                  # Workflow-level retry for task failures
                  retryStrategy:
                    limit: 3
                    backoff:
                      duration: "10s"
                      factor: 2
    # Trigger-level retry for submission failures
    retryStrategy:
      steps: 3
      duration: 5s
      factor: 2
```

**Two retry scopes:**

- **Trigger retry**: Handles failures submitting the workflow (API errors, admission webhook failures)
- **Workflow retry**: Handles failures inside the workflow (task errors, container crashes)

---

## HTTP Trigger Retry

HTTP endpoints often return transient errors:

```yaml
triggers:
  - template:
      name: notify-slack
      http:
        url: https://hooks.slack.com/services/XXX
        method: POST
        payload:
          - src:
              dependencyName: event
              dataKey: body.message
            dest: text
    retryStrategy:
      steps: 5
      duration: 2s
      factor: 2
      jitter: 0.3
```

This handles Slack's rate limiting and temporary outages gracefully.

---

## Kubernetes Resource Retry

K8s API calls can fail due to conflicts or temporary unavailability:

```yaml
triggers:
  - template:
      name: create-configmap
      k8s:
        operation: create
        source:
          resource:
            apiVersion: v1
            kind: ConfigMap
            metadata:
              generateName: event-data-
            data:
              payload: ""
    retryStrategy:
      steps: 3
      duration: 1s
      factor: 2
```

Short initial delays work well for K8s API retries since failures are usually brief.

---

## When Retries Exhaust

After all retry attempts fail, the event is dropped by default. To preserve failed events:

1. **Dead Letter Queue**: Route failed events to a separate topic for later processing
2. **Error Workflows**: Trigger an error-handling workflow on final failure
3. **Alerting**: Send notifications when retries exhaust

See [Dead Letter Queues](dead-letter.md) for failed event handling.

---

## Retry vs. Idempotency

Retries can cause duplicate processing. If a trigger succeeds but the acknowledgment fails, the event may be processed again. Your workflows must handle this:

```yaml
# Idempotent workflow design
spec:
  templates:
    - name: deploy
      script:
        source: |
          # Check if already deployed
          CURRENT=$(kubectl get deployment my-app -o jsonpath='{.spec.template.spec.containers[0].image}')
          if [ "$CURRENT" == "{{inputs.parameters.image}}" ]; then
            echo "Already at target version, skipping"
            exit 0
          fi
          # Proceed with deployment
          kubectl set image deployment/my-app app={{inputs.parameters.image}}
```

---

!!! tip "Retry Budgets"
    Calculate your retry budget: `steps × duration × factor^steps`. Long retry chains can delay subsequent events. Keep total retry time under your acceptable latency threshold.

---

## Related

- [Dead Letter Queues](dead-letter.md) - Handle exhausted retries
- [Backpressure Handling](backpressure.md) - Prevent overload during retries
- [Workflow Retry Strategy](../../argo-workflows/templates/retry-strategy.md) - Workflow-level retries
- [Official Retry Docs](https://argoproj.github.io/argo-events/sensors/triggers/intro/#policy) - Complete reference
