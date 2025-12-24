---
date: 2025-12-24
authors:
  - mark
categories:
  - Kubernetes
  - Performance
  - DevSecOps
description: >-
  Argo workflows hitting API limits. 100+ calls per execution. The volume mount pattern that dropped it to zero.
slug: configmap-cache-zero-api
---

# Zero API Calls: The ConfigMap Pattern That Changed Everything

The workflows were slowing down. Not dramatically. Just... gradually. Week by week.

Then the logs started showing warnings: `API rate limit approaching threshold`.

100+ workflows per day. Each workflow making 2-3 Kubernetes API calls to read ConfigMaps. That's 200-300 API requests per day. Not sustainable.

<!-- more -->

---

## The Creeping Problem

The pattern was simple: workflows needed lookup data.

- Which namespace does this repo belong to?
- What's the artifact path for this project?
- Where should this deployment go?

The solution was obvious: store mappings in a ConfigMap. Read them when needed.

```yaml
- name: get-namespace
  template: lookup-config
  arguments:
    parameters:
      - name: repo
        value: "{{workflow.parameters.repo}}"
```

Each lookup: one API call. `kubectl get configmap workflow-cache -o json`.

**100 workflows per day × 2 lookups per workflow = 200 API calls.**

The workflows worked. Then they slowed. Logs filled with API request traces. Rate limit warnings appeared.

We'd built a system that worked against itself at scale.

---

## The Standard Approaches Failed

### Cache in Memory

Doesn't work. Workflows run in isolated containers. No shared state. Each execution starts fresh.

### Hardcode the Data

Defeats the purpose. Data changes weekly. Hardcoding means code changes for every mapping update.

### External Database

Overkill. We're talking about 50 lines of key-value pairs, not a relational data model.

### Reduce API Calls

Tried batching lookups. Tried caching within a workflow. Still making API calls. Still hitting rate limits.

The problem wasn't *how many* API calls. It was that we needed API calls at all.

---

## The Breakthrough: ConfigMaps Are Files

ConfigMaps aren't just API objects. They're **volume mounts**.

You can mount a ConfigMap as a read-only volume in a Pod. The data becomes... a file.

```yaml
volumes:
  - name: cache-volume
    configMap:
      name: workflow-cache
```

No API call needed. The file is there before the script runs. Read it with `cat`. Parse it with `jq`. Standard file I/O.

**Zero API overhead.**

The realization hit during a documentation dive. Volume mounts. Not API calls. *Volume mounts*.

---

## The Implementation

ConfigMap with JSON data:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-cache
data:
  mappings.json: |
    {
      "repo-to-namespace": {
        "adaptive-enforcement-lab/readability": "tools",
        "adaptive-enforcement-lab/scorecard-utils": "security"
      }
    }
```

Workflow script reads from mounted volume:

```bash
#!/bin/bash
REPO="$1"

# No API call: just read the file
NAMESPACE=$(jq -r --arg repo "$REPO" \
  '.["repo-to-namespace"][$repo] // "default"' /cache/mappings.json)

echo "Deploying $REPO to namespace: $NAMESPACE"
```

Volume mount configuration:

```yaml
volumeMounts:
  - name: cache-volume
    mountPath: /cache
    readOnly: true
```

**That's it.** No client libraries. No API tokens. No rate limits. Just... read a file.

---

## The Results

Before:

- Workflow execution: 2 to 3 seconds
- API calls per workflow: 2 or 3
- Total API calls per day: 200 to 300
- Logs: Cluttered with `GET /api/v1/configmaps/...`
- Rate limit warnings: Weekly

After:

- Workflow execution: 200ms to 300ms
- API calls per workflow: 0
- Total API calls per day: 0
- Logs: Clean (just workflow logic)
- Rate limit warnings: None

10x faster. Zero API calls. Five lines of YAML.

---

## The Shift in Thinking

We'd been treating ConfigMaps as **API objects that store data**.

They're actually **files that can be read without API calls**.

The pattern works everywhere:

- **Argo Workflows**: Repository mappings, artifact paths
- **Kubernetes Jobs**: Environment configurations, lookup tables
- **CronJobs**: Static reference data (catalogs, pricing tiers)

Any scenario where:

1. Data changes infrequently (daily, weekly)
2. Lookups happen frequently (per workflow, per job)
3. API overhead matters (latency, rate limits)

Volume mount wins. Every time.

---

## The Trade-Off

ConfigMap updates require pod restarts to pick up changes. For Deployments, that's `kubectl rollout restart`. For workflows, it's automatic. The next execution picks up the new data.

The trade-off: **Eventual consistency for zero API overhead.**

Worth it? Absolutely. Our data changed weekly. Workflows ran hundreds of times per day. The math was obvious.

---

## The Pattern Everywhere

Once you see it, you see it everywhere:

- Application configs (database URLs, feature flags)
- Static reference data (category mappings, product catalogs)
- Workflow orchestration (namespace mappings, deployment targets)

The question isn't "Should I use an API?" It's "Do I need an API?"

If the data is static or changes infrequently, the answer is no. Mount it. Read it. Move on.

---

## What Changed

**Before**: "ConfigMaps need API calls to read."

**After**: "ConfigMaps are files. Files don't need API calls."

Workflow latency dropped from seconds to milliseconds. API rate limits disappeared. Logs cleaned up.

The pattern that fixed everything: stop treating configuration as an API problem. Treat it as a file system problem.

!!! tip "Implementation Guide"
    See [ConfigMap as Cache Pattern](../../build/efficiency-patterns/configmap-cache.md) for volume mount configuration, script examples, and refresh strategies.

---

## Related Patterns

- [Go CLI Architecture: Kubernetes Integration](../../build/go-cli-architecture/kubernetes-integration/) for client-go patterns vs volume mounts
- [Argo Workflows](../../enforce/policy-as-code/runtime-deployment/) for workflow orchestration patterns

---

*Zero API calls. Sub-millisecond lookups. The volume mount pattern that nobody talks about. ConfigMaps aren't API objects. They're files. Treat them like files. Everything gets faster.*
