---
description: >-
  Handle transient failures with exponential backoff and retry policies. Configure per-step retries, avoid tight loops, and distinguish permanent vs temporary errors.
---

# Retry Strategy

Transient failures are inevitable in distributed systems. API servers become temporarily unavailable. Rate limits kick in during bursts. Network partitions resolve themselves after seconds. A well-designed retry strategy handles these without human intervention.

---

## Why Retry Matters

The first instinct when a workflow fails is to check what went wrong. But many failures fix themselves. A Kubernetes API server might return a 503 for a few seconds during a rolling update. A rate-limited external API recovers after the quota window resets.

Without retry logic, these transient issues become permanent failures. Someone has to notice, investigate, and manually re-trigger the workflow. This breaks the promise of automation. The system should handle routine failures on its own.

The flip side is that not everything should be retried. An RBAC permission denied error won't fix itself. Invalid parameters won't become valid. A deleted resource won't reappear. Retrying these wastes time and can mask real problems.

---

## Configuration

```yaml
templates:
  - name: restart-deployments
    retryStrategy:
      limit: 3
      retryPolicy: Always
      backoff:
        duration: "5s"
        factor: 2
        maxDuration: "1m"
```

The `backoff` configuration implements exponential backoff: first retry after 5 seconds, second after 10 seconds, third after 20 seconds. This gives transient issues time to resolve while avoiding tight retry loops that can worsen the problem.

**Configuration options:**

| Field | Purpose | Example |
| ------- | --------- | --------- |
| `limit` | Maximum retry attempts | `3` |
| `retryPolicy` | When to retry | `Always`, `OnFailure`, `OnError` |
| `backoff.duration` | Initial wait time | `"5s"` |
| `backoff.factor` | Multiplier for each retry | `2` |
| `backoff.maxDuration` | Cap on wait time | `"1m"` |

---

## Retry Policies

The `retryPolicy` field controls which failures trigger retries:

**`Always`**: Retry on any failure: script errors, container crashes, and timeouts. Use this when you can't predict failure modes and want maximum resilience.

**`OnFailure`**: Retry only when the container exits with a non-zero code. System errors (like pod eviction) don't trigger retries. Use this when you trust your script to handle transient issues internally.

**`OnError`**: Retry only on system errors, not script failures. Use this when script failures represent permanent problems that shouldn't be retried.

---

## When to Retry

| Failure Type | Retry? | Why |
| -------------- | -------- | ----- |
| API rate limits | Yes | Backoff gives quota time to reset |
| Network timeouts | Yes | Transient by nature |
| 5xx server errors | Yes | Usually temporary |
| Pod eviction | Yes | Cluster pressure is temporary |
| RBAC denied | No | Won't fix itself |
| Invalid parameters | No | Need human correction |
| Resource not found | Maybe | Depends on whether it might appear |

The "maybe" category requires judgment. If your workflow expects a resource that another workflow creates, a brief retry period makes sense. The resource might appear momentarily. But if the resource should already exist, failing fast is better.

---

## Backoff Tuning

The backoff configuration balances responsiveness against load:

```mermaid
flowchart LR
    A[Fail] -->|5s| B[Retry 1]
    B -->|Fail| C[10s wait]
    C -->|Retry 2| D[Fail]
    D -->|20s wait| E[Retry 3]
    E -->|Fail| F[Permanent Failure]

    %% Ghostty Hardcore Theme
    style A fill:#f92572,color:#1b1d1e
    style B fill:#fd971e,color:#1b1d1e
    style C fill:#65d9ef,color:#1b1d1e
    style D fill:#fd971e,color:#1b1d1e
    style E fill:#65d9ef,color:#1b1d1e
    style F fill:#f92572,color:#1b1d1e

```

**Aggressive backoff** (short duration, low factor): Faster recovery from brief blips, but more load on failing systems. Use for internal APIs that can handle the traffic.

**Conservative backoff** (long duration, high factor): Slower recovery, but gentler on systems under stress. Use for external APIs with rate limits.

!!! warning "Retry Limits"
    Set `limit` based on your tolerance for delay. Three retries with exponential backoff can take over a minute. If your workflow is time-sensitive, consider fewer retries with shorter backoff.

---

## Per-Step Retries

Different steps can have different retry strategies:

```yaml
templates:
  - name: main
    steps:
      - - name: fetch-data
          template: fetch-data
      - - name: process-data
          template: process-data

  - name: fetch-data
    retryStrategy:
      limit: 5
      backoff:
        duration: "10s"
        factor: 2
    container:
      image: curlimages/curl
      command: [curl, "{{inputs.parameters.url}}"]

  - name: process-data
    retryStrategy:
      limit: 2
      backoff:
        duration: "5s"
        factor: 1
    container:
      image: processor:latest
      command: [process, /data/input.json]
```

The `fetch-data` step uses aggressive retries because network requests are prone to transient failures. The `process-data` step uses minimal retries because processing failures are usually permanent. The input is either valid or it isn't.

---

## Combining with Timeouts

Retry strategies interact with timeouts. A step with both retry and timeout might:

1. Run the step
2. Hit the timeout
3. Retry
4. Hit the timeout again
5. Eventually fail permanently

Consider the total time budget:

```yaml
spec:
  activeDeadlineSeconds: 300  # 5 minute workflow timeout
  templates:
    - name: process
      retryStrategy:
        limit: 3
        backoff:
          duration: "30s"  # Retry delays: 30s, 60s, 120s = 210s total
```

With three retries and exponential backoff starting at 30 seconds, the retry delays alone consume 210 seconds. Add actual execution time and you might exceed the 300-second workflow timeout. Always calculate worst-case timing.

---

## Related

- [Basic Structure](basic-structure.md) - WorkflowTemplate anatomy
- [Init Containers](init-containers.md) - Multi-stage setup
- [Concurrency Control](../concurrency/index.md) - Preventing parallel execution conflicts
