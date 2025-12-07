# Backpressure Handling

When events arrive faster than they can be processed, systems must apply backpressure—slowing or rejecting new events to prevent overload. Without backpressure, queues grow unbounded, memory exhausts, and systems crash.

---

## Backpressure Points

Multiple components can become bottlenecks:

```mermaid
flowchart LR
    A[Event Storm] --> B[EventSource]
    B -->|Backpressure| C[EventBus]
    C -->|Backpressure| D[Sensor]
    D -->|Backpressure| E[Workflows]

    style A fill:#f92572,color:#1b1d1e
    style B fill:#fd971e,color:#1b1d1e
    style C fill:#515354,color:#f8f8f3
    style D fill:#f92572,color:#1b1d1e
    style E fill:#a7e22e,color:#1b1d1e
```

Each component needs its own backpressure configuration.

---

## EventBus Limits

Configure JetStream to limit queue depth:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
spec:
  jetstream:
    version: "2.9.11"
    settings: |
      max_msgs: 100000
      max_bytes: 1073741824
      max_msg_size: 1048576
      max_consumers: 100
```

| Setting | Purpose | Behavior When Exceeded |
|---------|---------|----------------------|
| `max_msgs` | Maximum messages in stream | New messages rejected |
| `max_bytes` | Maximum total bytes | New messages rejected |
| `max_msg_size` | Maximum single message size | Message rejected |
| `max_consumers` | Maximum concurrent consumers | New consumers rejected |

---

## Sensor Rate Limiting

Limit how fast a Sensor processes events:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: rate-limited
spec:
  # Sensor-level rate limiting
  rateLimit:
    requestsPerUnit: 10
    unit: minute

  dependencies:
    - name: high-volume-event
      eventSourceName: source
      eventName: event

  triggers:
    - template:
        name: process
        argoWorkflow:
          # ...
```

This limits the Sensor to 10 workflow submissions per minute, regardless of how many events arrive.

---

## Trigger Rate Limiting

Apply rate limits to individual triggers:

```yaml
triggers:
  - template:
      name: api-call
      http:
        url: https://api.example.com/webhook
        method: POST
    rateLimit:
      requestsPerUnit: 100
      unit: second
```

Different triggers can have different limits based on downstream capacity.

---

## Workflow Concurrency

Use Argo Workflows concurrency controls as a final backpressure mechanism:

```yaml
# Semaphore limits concurrent workflows
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-semaphores
data:
  api-calls: "5"
```

```yaml
# Workflow references semaphore
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: api-consumer
spec:
  synchronization:
    semaphore:
      configMapKeyRef:
        name: workflow-semaphores
        key: api-calls
  templates:
    - name: main
      # ...
```

New workflows wait when semaphore is full. See [Semaphore Patterns](../../argo-workflows/concurrency/semaphores.md) for details.

---

## Handling Rejected Events

When backpressure rejects events, you have options:

### 1. Drop Silently

Acceptable for truly optional events (metrics, telemetry):

```yaml
# No special handling - events simply don't arrive
```

### 2. Return Error to Source

Let the event producer retry:

```yaml
# EventSource configured to not acknowledge
spec:
  pubsub:
    event:
      ackWaitTime: "30s"  # Time to process before nack
```

### 3. Store for Later

Write to persistent storage for batch processing:

```yaml
triggers:
  - template:
      name: store-for-later
      k8s:
        operation: create
        source:
          resource:
            apiVersion: v1
            kind: ConfigMap
            metadata:
              generateName: backlog-
            data:
              event: ""
```

---

## Monitoring Backpressure

Watch these metrics for backpressure issues:

| Metric | Warning Sign |
|--------|--------------|
| EventBus queue depth | Consistently near max_msgs |
| Sensor processing latency | Increasing over time |
| Workflow pending count | Growing queue of waiting workflows |
| Event age | Events sitting in queue for minutes |

```bash
# Check EventBus queue depth (JetStream)
kubectl exec -n argo-events eventbus-default-0 -- \
  nats stream info default --json | jq '.state.messages'

# Check pending workflows
kubectl get workflows -n argo-workflows --field-selector status.phase=Pending | wc -l
```

---

!!! tip "Design for Peak Load"
    Size your backpressure limits for peak load, not average. A system that handles normal traffic but collapses under spikes isn't production-ready. Test with realistic load patterns.

---

## Related

- [Retry Strategies](retry.md) - Handle transient failures
- [Semaphore Patterns](../../argo-workflows/concurrency/semaphores.md) - Workflow concurrency
- [High Availability](high-availability.md) - Scale for throughput
