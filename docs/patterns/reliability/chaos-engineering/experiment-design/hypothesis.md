---
title: Hypothesis Formation
description: >-
  Hypothesis formation for chaos experiments. Structure hypotheses with given-when-then-and format, define observable outcomes, and create specific testable predictions.
tags:
  - chaos-engineering
  - hypothesis
  - experiment-design
---
# Hypothesis Formation

Start with a question about system behavior under failure conditions.

!!! tip "Start Specific"
    Don't hypothesize "system is resilient". Hypothesize "payment service continues processing with Redis down" or "frontend loads with API degraded to cache-only".

## Good Hypothesis Structure

```text
Given: [Normal operating conditions]
When: [Specific failure injected]
Then: [Expected system behavior]
And: [Observable metrics that validate behavior]
```

## Example Hypotheses

### Hypothesis 1: Pod Deletion Recovery

```text
Given: API gateway with 3 replicas
When: One pod is killed
Then: Traffic redirects to remaining replicas within 5 seconds
And: Error rate stays below 0.5%, P99 latency increases < 50ms
```

### Hypothesis 2: Database Latency Degradation

```text
Given: Application with database dependency
When: Database query latency increases to 500ms
Then: Circuit breaker opens after 5 failures
And: Fallback cache activates, error rate < 5%
```

### Hypothesis 3: Memory Pressure Handling

```text
Given: Background worker with memory limits
When: Memory usage approaches 256MB limit
Then: Application triggers garbage collection and defers tasks
And: Pod remains responsive (health checks pass)
```

## Hypothesis Guidelines

### Be Concrete

**Bad**: "System handles pod failures gracefully"

**Good**: "When 1 of 3 API pods is killed, requests fail for < 5 seconds and error rate remains < 0.5%"

### Include Metrics

Every hypothesis needs observable outcomes:

- Error rate thresholds
- Latency percentiles
- Recovery time windows
- Availability targets

### Scope the Blast Radius

Define exactly what you're testing:

- Which service/component
- How many replicas/instances
- For how long
- Under what conditions

### State the Expected Behavior

Don't just describe the failure. Describe how the system should respond:

- Failover mechanisms activate
- Circuit breakers open
- Caches serve stale data
- Graceful degradation occurs

## From Question to Hypothesis

### Step 1: Identify the Question

"What happens if Redis goes down?"

### Step 2: Make it Specific

"What happens if Redis is unavailable during peak traffic?"

### Step 3: Add Observable Outcomes

"When Redis is unavailable, does the session store fallback activate within 30 seconds?"

### Step 4: Define Success Criteria

```text
Given: Web application with Redis session store and Postgres fallback
When: Redis is killed for 2 minutes during peak traffic (1000 req/s)
Then: Session store switches to Postgres within 30 seconds
And: Error rate < 5%, P99 latency < 2s, no session data loss
```

## Common Hypothesis Patterns

### Pattern: Service Dependency Failure

```text
Given: [Service A] depends on [Service B]
When: [Service B] becomes unavailable
Then: [Service A] activates [fallback mechanism]
And: [Metrics remain within SLO bounds]
```

### Pattern: Resource Exhaustion

```text
Given: [Component] with [resource limit]
When: [Resource usage] approaches [limit]
Then: [Component] activates [protection mechanism]
And: [Service continues operating with degraded performance]
```

### Pattern: Network Partition

```text
Given: [Distributed system] with [N replicas]
When: [Network partition] isolates [X replicas]
Then: [Quorum mechanism] maintains [consistency guarantee]
And: [Recovery occurs] within [time bound]
```

## Related Topics

- **[Success Criteria](success-criteria.md)** - Define measurable outcomes
- **[Blast Radius Control](blast-radius.md)** - Scope experiment impact
- **[Experiment Design Overview](index.md)** - Complete methodology

---

*Every chaos experiment starts with a specific, measurable hypothesis. If you can't state what you expect to happen, you're not ready to inject chaos.*
