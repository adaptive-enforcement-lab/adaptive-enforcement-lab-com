---
title: Common Patterns
description: >-
  Debug frequent Argo Events issues with proven solutions. Fix JSON parsing failures, dependency mismatches, namespace conflicts, and webhook delivery problems.
---
# Common Patterns

Frequently encountered issues and their solutions. These patterns appear across different EventSource types and Sensor configurations.

---

## "Nothing Happens" Checklist

When events don't trigger workflows, check in order:

| Step | Check | Command |
| ------ | ------- | --------- |
| 1 | EventSource running | `kubectl get eventsources -n argo-events` |
| 2 | EventSource receiving | `kubectl logs -l eventsource-name=<name>` |
| 3 | EventBus healthy | `kubectl get eventbus -n argo-events` |
| 4 | Sensor running | `kubectl get sensors -n argo-events` |
| 5 | Sensor receiving | `kubectl logs -l sensor-name=<name>` |
| 6 | Workflows created | `kubectl get workflows -n argo-workflows` |

Stop at the first failure. That's where your problem is.

---

## Pattern: JSON Body Not Parsed

**Symptom**: Events arrive, filters don't match, no errors.

**Cause**: Pub/Sub, Kafka, and other messaging systems wrap messages. Without explicit parsing, the body is a string.

**Fix**:

```yaml
# Pub/Sub
spec:
  pubsub:
    event:
      jsonBody: true  # Required for JSON parsing

# Kafka
spec:
  kafka:
    event:
      jsonBody: true

# Webhook (usually automatic, but can set explicitly)
spec:
  webhook:
    event:
      jsonBody: true
```

---

## Pattern: Wrong Dependency Name

**Symptom**: Sensor logs show event received, but trigger parameter injection fails.

**Cause**: `dependencyName` in trigger doesn't match dependency definition.

```yaml
# Wrong - names don't match
dependencies:
  - name: image-push            # Defined as "image-push"

triggers:
  - template:
      parameters:
        - src:
            dependencyName: push  # References "push" - doesn't exist!
```

```yaml
# Correct - names match
dependencies:
  - name: image-push

triggers:
  - template:
      parameters:
        - src:
            dependencyName: image-push  # Matches dependency name
```

---

## Pattern: EventSource/Sensor Name Mismatch

**Symptom**: Sensor never receives events.

**Cause**: Sensor dependency references wrong EventSource or event name.

```yaml
# EventSource defines
metadata:
  name: github-events  # EventSource name
spec:
  github:
    push:              # Event name is "push"

# Sensor must match exactly
dependencies:
  - name: my-dep
    eventSourceName: github-events  # Must match EventSource name
    eventName: push                  # Must match event name in spec
```

---

## Pattern: Namespace Mismatch

**Symptom**: Components running but not connected.

**Cause**: EventSource, EventBus, and Sensor must be in the same namespace.

```bash
# Check namespaces match
kubectl get eventsources,eventbus,sensors -A | grep -E "NAME|argo"
```

If they're in different namespaces, events won't flow between them.

---

## Pattern: Default EventBus Not Found

**Symptom**: EventSource or Sensor fails with "eventbus not found".

**Cause**: Components look for EventBus named `default` unless specified.

**Fix**: Either create default EventBus:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default  # Must be named "default"
  namespace: argo-events
spec:
  jetstream:
    version: "2.9.11"
```

Or specify EventBus name in components:

```yaml
spec:
  eventBusName: my-custom-eventbus
```

---

## Pattern: Trigger Fires Multiple Times

**Symptom**: Same event triggers multiple workflow executions.

**Causes**:

1. **Multiple Sensor replicas with bug**: Older versions had deduplication issues
2. **Event republished**: Source system sending duplicates
3. **Retry after partial success**: Trigger succeeded but ack failed

**Fix**: Make workflows idempotent (see [Idempotency Patterns](../../../patterns/efficiency/idempotency/index.md)).

---

## Pattern: Old Events Replaying

**Symptom**: Events from hours/days ago suddenly trigger.

**Cause**: EventBus persistence replaying unacknowledged messages after restart.

**Fix**: Configure message retention:

```yaml
spec:
  jetstream:
    settings: |
      max_age: "1h"  # Messages expire after 1 hour
```

Or investigate why messages weren't acknowledged (Sensor failure, slow processing).

---

## Pattern: Sensor Restart Loop

**Symptom**: Sensor pod repeatedly restarts.

**Common causes**:

1. **Invalid trigger spec**: Malformed YAML crashes sensor

    ```bash
    kubectl describe pod -l sensor-name=<name> | grep -A10 "Events:"
    ```

2. **Memory exhaustion**: Event volume too high

    ```bash
    kubectl top pod -l sensor-name=<name>
    ```

3. **Dependency error**: Can't connect to EventBus

    ```bash
    kubectl logs -l sensor-name=<name> --previous
    ```

---

## Pattern: GitHub Webhooks Not Arriving

**Symptom**: GitHub configured, EventSource running, no events.

**Checklist**:

1. **Webhook delivery status**: GitHub repo → Settings → Webhooks → Recent Deliveries
2. **Secret mismatch**: GitHub secret must match EventSource secret
3. **SSL issues**: GitHub requires valid SSL for webhook URLs
4. **Firewall**: External traffic must reach your cluster

```bash
# Test external accessibility
curl -I https://your-webhook-url.example.com/github

# Check GitHub's view
# In GitHub webhook settings, look for red X marks on recent deliveries
```

---

## Pattern: Rate Limiting Upstream

**Symptom**: EventSource works initially, then stops receiving.

**Cause**: External system rate limiting your requests.

**Fix**: Add delays or reduce polling frequency:

```yaml
# For polling EventSources
spec:
  calendar:
    example:
      interval: 60s  # Don't poll too frequently
```

For webhook-based sources, this isn't usually an issue.

---

!!! tip "Log Everything First"
    When debugging, enable debug logging on all components temporarily. The performance hit is worth the visibility. Disable after resolving the issue.

---

## Related

- [EventSource Issues](eventsources.md) - EventSource-specific debugging
- [Sensor Issues](sensors.md) - Sensor-specific debugging
- [Reliability Patterns](../../../patterns/argo-events/reliability/index.md) - Prevent issues proactively
