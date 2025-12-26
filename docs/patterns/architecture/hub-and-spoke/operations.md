---
title: Hub and Spoke Operations Guide
description: >-
  Scaling characteristics, failure isolation, result aggregation, and monitoring strategies for hub-and-spoke distributed workflow patterns in production.
---

# Hub and Spoke Operations Guide

## Scaling Characteristics

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

| Aspect | Sequential | Hub and Spoke |
| -------- | ------------ | --------------- |
| Parallelism | None | Full |
| Time complexity | O(n) | O(1), limited by longest spoke |
| Resource usage | One worker | n workers |
| Failure isolation | One failure stops all | Failures isolated to spokes |
| Debugging | Easy, linear flow | Harder, distributed system |

---

## Failure Handling

Spoke failures don't kill the hub:

```yaml
- name: spawn-spoke
  inputs:
    parameters:
      - name: repo
  continueOn:
    failed: true  # Hub continues if spoke fails
  resource:
    action: create
    manifest: |
      spec:
        retryStrategy:
          limit: 3
          backoff:
            duration: 30s
            factor: 2
```

Hub spawns all spokes. Failed spokes retry independently. Hub summarizes successes and failures.

---

## Summary Collection

Hub aggregates spoke results:

```yaml
- name: summarize
  inputs:
    parameters:
      - name: spoke-results
  script:
    image: alpine:latest
    command: [sh]
    source: |
      #!/bin/sh
      RESULTS='{{inputs.parameters.spoke-results}}'

      TOTAL=$(echo "$RESULTS" | jq 'length')
      SUCCESS=$(echo "$RESULTS" | jq '[.[] | select(.status=="success")] | length')
      FAILED=$(echo "$RESULTS" | jq '[.[] | select(.status=="failed")] | length')

      echo "Total: $TOTAL"
      echo "Success: $SUCCESS"
      echo "Failed: $FAILED"

      if [ "$FAILED" -gt 0 ]; then
        echo "Failed repositories:"
        echo "$RESULTS" | jq -r '.[] | select(.status=="failed") | .repository'
        exit 1
      fi
```

---

## Rate Limiting and Throttling

Prevent overwhelming downstream systems. Control spoke execution rate.

### Max Parallel Constraint

Limit concurrent spokes:

```yaml
# Argo Workflows: limit parallelism
- name: spawn-spoke
  inputs:
    parameters:
      - name: repo
  withParam: "{{workflow.parameters.repositories}}"
  parallelism: 10  # Maximum 10 spokes running concurrently
  resource:
    action: create
    manifest: |
      spec:
        workflowTemplateRef:
          name: spoke-worker
```

GitHub Actions matrix with concurrency:

```yaml
jobs:
  distribute:
    runs-on: ubuntu-latest
    strategy:
      max-parallel: 5  # Only 5 repos processed at once
      matrix:
        repo: ${{ fromJson(needs.discover.outputs.repositories) }}
    steps:
      - run: ./process-repo.sh ${{ matrix.repo }}
```

### Batch Processing with Waves

Split work into waves:

```yaml
# Hub splits 100 repos into 10 waves of 10
- name: process-wave
  inputs:
    parameters:
      - name: wave-number
      - name: repositories
  steps:
    - - name: spawn-batch
        template: spawn-spoke
        arguments:
          parameters:
            - name: repo
              value: "{{item}}"
        withParam: "{{inputs.parameters.repositories}}"
        parallelism: 10

    # Wait between waves
    - - name: wait
        template: sleep
        arguments:
          parameters:
            - name: duration
              value: "30s"
```

Wave execution prevents API rate limit hits.

### Exponential Backoff for Rate Limits

Spoke detects rate limit, backs off:

```go
func executeWithBackoff(ctx context.Context, repo string) error {
    maxRetries := 5
    baseDelay := 1 * time.Second

    for attempt := 0; attempt < maxRetries; attempt++ {
        err := processRepository(ctx, repo)
        if err == nil {
            return nil
        }

        // Check if rate limited
        if isRateLimitError(err) {
            delay := baseDelay * time.Duration(1<<attempt) // 1s, 2s, 4s, 8s, 16s
            log.Printf("Rate limited, backing off for %v", delay)
            time.Sleep(delay)
            continue
        }

        // Non-rate-limit error, fail
        return err
    }

    return fmt.Errorf("max retries exceeded for %s", repo)
}

func isRateLimitError(err error) bool {
    // GitHub API returns 403 with rate limit headers
    if httpErr, ok := err.(*github.RateLimitError); ok {
        return true
    }
    return false
}
```

### Rate Limit Detection and Handling

Check rate limits before spawning spokes:

```yaml
- name: check-rate-limit
  script:
    image: ghcr.io/cli/cli:latest
    command: [bash]
    source: |
      #!/bin/bash
      set -euo pipefail

      # Get GitHub API rate limit
      LIMIT=$(gh api rate_limit --jq '.rate.remaining')
      RESET=$(gh api rate_limit --jq '.rate.reset')

      if [ "$LIMIT" -lt 100 ]; then
        WAIT=$((RESET - $(date +%s)))
        echo "Rate limit low ($LIMIT remaining). Waiting ${WAIT}s"
        sleep "$WAIT"
      fi

      echo "Rate limit OK: $LIMIT requests remaining"
```

Hub respects rate limits before distributing work.

---

## When to Use This Pattern

**Use when:**

- Work can be parallelized
- Same operation across many targets (repos, deployments, files)
- Scaling matters more than simplicity
- Failures should be isolated

**Don't use when:**

- Tasks must run sequentially
- Coordination overhead exceeds work duration
- Debugging distributed systems is too complex

---

## Real-World Scenarios

### Scenario 1: File Distribution

Hub discovers 75 repositories. Spawns 75 spoke workflows in parallel. Each spoke creates a PR. Hub summarizes: 70 success, 5 failed (protected branches).

Time: 2 minutes (parallelized) vs 2.5 hours (sequential).

### Scenario 2: Deployment Restart

Hub receives image push event. Looks up deployments using that image (via [ConfigMap cache](../../../blog/posts/2025-12-03-configmap-cache-zero-api.md)). Spawns spoke for each deployment. Each spoke restarts independently.

Isolation: One deployment failure doesn't block others.

### Scenario 3: Multi-Cluster Operations

Hub coordinates operations across 10 Kubernetes clusters. Spawns spoke for each cluster. Spokes execute in parallel using cluster-specific credentials.

Scale: Add clusters without changing hub logic.

---

## Monitoring Hub and Spoke

Track hub and spoke metrics separately:

```yaml
# Prometheus metrics
# Hub duration
argo_workflow_duration_seconds{workflow_template="hub-orchestrator"}

# Spoke success rate
sum(argo_workflow_status{workflow_template="spoke-worker",phase="Succeeded"})
/
sum(argo_workflow_status{workflow_template="spoke-worker"})

# Active spokes
count(argo_workflow_status{workflow_template="spoke-worker",phase="Running"})
```

Alert when:

- Hub fails (critical: no spokes spawn)
- Spoke failure rate > 10% (degraded operation)
- Spokes stuck running (timeout issue)

---

## Related Patterns

- **[Separation of Concerns](../separation-of-concerns/index.md):** Hub is orchestrator, spokes are executors
- **[Three-Stage Design](../../architecture/three-stage-design.md):** Discovery → Distribution → Summary
- **[Matrix Distribution](../../architecture/matrix-distribution/index.md):** GitHub Actions equivalent

---

*The hub spawned 100 spokes. 99 succeeded. 1 failed. The hub reported both. The system scaled. The failure was isolated. The operation completed in minutes, not hours.*
