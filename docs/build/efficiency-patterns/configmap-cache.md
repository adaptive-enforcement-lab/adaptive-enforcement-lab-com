---
tags:
  - kubernetes
  - performance
  - caching
  - configmap
  - argo-workflows
  - patterns
  - developers
  - operators
description: >-
  ConfigMap as volume mount pattern for zero-API-overhead caching in Kubernetes workflows and jobs. Sub-millisecond lookups, no rate limits, clean implementation.
---

# ConfigMap as Cache Pattern

Zero-API-overhead caching for Kubernetes workflows and jobs. Volume mount pattern for sub-millisecond lookups without Kubernetes API calls.

!!! tip "Key Benefit"
    ConfigMap volume mounts eliminate API calls entirely. Read from a file instead of calling the Kubernetes API. Sub-millisecond lookups with zero rate limit risk.

---

## Problem Statement

Workflows and Jobs need lookup data: mappings, configurations, static lists, reference tables.

**Standard approaches fail**:

1. **API Calls**: Slow (network latency), rate-limited, logs cluttered with API requests
2. **Hardcoded Data**: Inflexible, requires code changes for data updates
3. **Database Lookups**: Overkill for static data, adds dependency complexity

**The gap**: Fast, dynamic, zero-API-overhead lookups.

---

## Volume Mount Pattern

ConfigMaps can be **mounted as read-only volumes** in Pods/Workflows.

Scripts read from the mounted file instead of making API calls. Data is available before the script runs. Zero API overhead.

### How It Works

```mermaid
graph LR
    A[ConfigMap with Cache Data] -->|Volume Mount| B[Pod/Workflow]
    B -->|Read File| C[Script]
    C -->|Sub-millisecond| D[Data Available]

    %% Ghostty Hardcore Theme
    style A fill:#65d9ef
    style B fill:#9e6ffe
    style C fill:#a7e22e
    style D fill:#fd971e

```

**Key Points**:

- ConfigMap created with cache data (JSON, flat files, YAML)
- Volume mounted at `/cache` or `/data` path
- Script reads file with `cat`, `jq`, standard file I/O
- Updates require ConfigMap update + pod restart (or wait for next workflow execution)

---

## Implementation

The [Implementation guide](implementation.md) covers:

- Creating ConfigMaps with cache data (JSON, flat files, YAML)
- Mounting ConfigMap as volume in Argo Workflows and Kubernetes Jobs
- Script patterns for reading mounted data (jq, grep, yq)

[View Implementation Guide →](implementation.md)

---

## Trade-offs

### Pros

- **Zero API overhead**: No Kubernetes API calls, no rate limits
- **Fast**: Sub-millisecond file reads
- **Simple**: Standard file I/O, no client libraries needed
- **Clean logs**: No "GET /api/v1/configmaps/..." noise
- **Works everywhere**: Argo Workflows, Kubernetes Jobs, CronJobs, Deployments

### Cons

- **Static data**: ConfigMap must be updated for data changes
- **Pod restart required**: Changes require pod restart (or wait for next workflow execution)
- **Size limits**: ConfigMaps limited to 1MB (sufficient for most lookup tables)

**When to use**:

- Lookup data changes infrequently (daily, weekly)
- Sub-millisecond latency required
- API rate limits are a concern
- Workflow executions are frequent (data refresh happens naturally)

**When NOT to use**:

- Data changes constantly (use database or API)
- Data exceeds 1MB (use external storage)
- Real-time updates required (use API or database)

---

## Refresh Strategies

The [Refresh Strategies guide](refresh-strategies.md) covers:

- Manual update with `kubectl create configmap`
- Automated refresh with CronJob
- Event-driven refresh on source data change
- RBAC for cache updater ServiceAccount

[View Refresh Strategies →](refresh-strategies.md)

---

## Use Cases

The [Use Cases guide](use-cases.md) covers:

- Argo Workflows: Repository mappings and artifact paths
- Kubernetes Jobs: Environment-specific configuration
- CronJobs: Static reference data (catalogs, pricing tiers)
- Performance improvements: 2 seconds → 200ms per workflow

[View Use Cases & Troubleshooting →](use-cases.md)

---

## Related Patterns

- Blog: [Zero API Calls: The ConfigMap Pattern](../../blog/posts/2025-12-24-configmap-cache-zero-api.md) - Discovery story
- [Go CLI Architecture - Kubernetes Integration](../go-cli-architecture/kubernetes-integration/index.md) - client-go patterns for API-based approaches
- [Argo Workflows Patterns](../../enforce/policy-as-code/runtime-deployment/index.md) - Workflow orchestration context

---

*Zero API calls. Sub-millisecond lookups. ConfigMap as volume. The pattern that dropped workflow latency from seconds to milliseconds. Read a file. Skip the API. Simple wins.*
