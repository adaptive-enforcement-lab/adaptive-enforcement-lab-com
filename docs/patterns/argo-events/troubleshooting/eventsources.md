---
title: EventSource Troubleshooting
description: >-
  Troubleshoot EventSource connectivity and authentication failures. Diagnose webhook delivery, Pub/Sub parsing, subscription conflicts, and network issues.
---
# EventSource Troubleshooting

EventSources connect to external systems. When they fail, events never enter the system. These issues are usually configuration, authentication, or network-related.

---

## Diagnostic Steps

### 1. Check EventSource Status

```bash
kubectl get eventsources -n argo-events

# Example output:
# NAME              STATUS    AGE
# github-webhook    True      5d
# pubsub-events     False     2h    # Problem here
```

`False` status indicates the EventSource isn't ready.

### 2. Check EventSource Conditions

```bash
kubectl describe eventsource pubsub-events -n argo-events
```

Look for:

- `Status: False` conditions with reasons
- Events section at the bottom for recent errors
- Container restart counts

### 3. Check Pod Logs

```bash
kubectl logs -n argo-events -l eventsource-name=pubsub-events
```

---

## Common Issues

### Authentication Failures

**Symptom**: EventSource pod running but no events arriving.

```text
ERROR: authentication failed: credential not found
```

**Fix**: Verify secret exists and has correct keys:

```bash
# Check secret exists
kubectl get secret gcp-pubsub-credentials -n argo-events

# Verify secret content
kubectl get secret gcp-pubsub-credentials -n argo-events -o jsonpath='{.data}' | jq

# Check EventSource references correct key
kubectl get eventsource pubsub-events -o yaml | grep -A5 credentialSecret
```

---

### Webhook Not Receiving Events

**Symptom**: EventSource running, external service configured, but no events.

**Diagnostic**:

```bash
# Check service exists
kubectl get svc -n argo-events | grep eventsource

# Test internal connectivity
kubectl run -n argo-events debug --rm -it --image=curlimages/curl -- \
  curl -v http://github-eventsource-svc:12000/push
```

**Common causes**:

1. **Ingress misconfiguration**: External URL not routing to service
2. **Port mismatch**: EventSource listening on different port than configured
3. **Endpoint path wrong**: GitHub sending to `/` but EventSource expects `/push`

```yaml
# Verify webhook configuration matches
spec:
  github:
    webhook:
      endpoint: /push      # Must match external path
      port: "12000"        # Must match service port
      url: https://hooks.example.com/github/push  # Must be reachable
```

---

### Pub/Sub Events Not Parsing

**Symptom**: Events arrive but trigger nothing.

**Root cause**: Missing `jsonBody: true` setting.

```yaml
# Wrong - events arrive as raw strings
spec:
  pubsub:
    event:
      topic: my-topic
      # Missing jsonBody

# Correct - events parsed as JSON
spec:
  pubsub:
    event:
      topic: my-topic
      jsonBody: true
```

Without `jsonBody: true`, the entire message is a string. JSON paths in Sensors fail silently.

---

### Subscription Already Exists

**Symptom**: EventSource fails to start with subscription error.

```text
ERROR: subscription "my-subscription" already exists
```

**Fix**: Either use the existing subscription or configure unique names:

```yaml
spec:
  pubsub:
    event:
      subscriptionID: "unique-subscription-name"
      # Or let it auto-generate:
      # deleteSubscriptionOnFinish: true  # Careful: loses messages on restart
```

---

### Resource Exhaustion

**Symptom**: EventSource OOMKilled or CPU throttled.

```bash
kubectl describe pod -n argo-events -l eventsource-name=high-volume

# Look for:
# Last State: Terminated
# Reason: OOMKilled
```

**Fix**: Increase resources:

```yaml
spec:
  template:
    container:
      resources:
        requests:
          memory: 256Mi
          cpu: 100m
        limits:
          memory: 512Mi
          cpu: 500m
```

---

### Network Policy Blocking

**Symptom**: EventSource can't reach external service.

```text
ERROR: dial tcp: i/o timeout
```

**Fix**: Verify NetworkPolicy allows egress:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-eventsource-egress
  namespace: argo-events
spec:
  podSelector:
    matchLabels:
      eventsource-name: pubsub-events
  policyTypes:
    - Egress
  egress:
    - to: []  # Allow all egress
```

---

## Verification Test

Create a simple webhook EventSource to verify the system works:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: test-webhook
  namespace: argo-events
spec:
  webhook:
    test:
      port: "12000"
      endpoint: /test
      method: POST
```

Test it:

```bash
# Port forward
kubectl port-forward -n argo-events svc/test-webhook-eventsource-svc 12000:12000

# Send test event
curl -X POST http://localhost:12000/test -d '{"test": "hello"}'

# Check logs for event receipt
kubectl logs -n argo-events -l eventsource-name=test-webhook --tail=5
```

If this works, the issue is with your specific EventSource configuration.

---

!!! tip "Start Simple"
    When debugging, reduce your EventSource to minimal configuration. Remove filters, transforms, and optional settings. Get basic connectivity working, then add complexity back.

---

## Related

- [EventSource Configuration](../setup/event-sources.md) - Setup reference
- [Sensor Issues](sensors.md) - Next debugging step
- [Official EventSource Docs](https://argoproj.github.io/argo-events/eventsources/setup/intro/) - Complete reference
