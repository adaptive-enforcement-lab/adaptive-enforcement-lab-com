---
title: Engineering Patterns
description: >-
  Battle-tested patterns for building resilient, secure automation.
  From idempotency to error handling, these patterns survive contact with production.
---

# Engineering Patterns

Patterns that survive contact with production.

This is a growing collection of engineering patterns distilled from real-world DevSecOps automation. Each pattern addresses a specific challenge in building resilient, secure systems across the software development lifecycle.

!!! abstract "What Makes a Pattern"

    Every pattern here has been:

    - **Battle-tested** in production environments
    - **Documented** with clear tradeoffs and decision criteria
    - **Illustrated** with concrete implementation examples

---

## Pattern Overview

| Category | Pattern | Question | Action |
|----------|---------|----------|--------|
| Implementation | [**Idempotency**](idempotency/index.md) | "Safe to repeat?" | Make reruns safe |
| Implementation | [**Graceful Degradation**](graceful-degradation/index.md) | "What if it fails?" | Fallback to slower alternatives |
| Implementation | **Fail Fast** | "Is something wrong?" | Stop immediately |
| Implementation | **Prerequisite Checks** | "Can it succeed?" | Validate before starting |
| Implementation | [**Work Avoidance**](work-avoidance/index.md) | "Already done?" | Skip redundant work |
| Workflow | [**Three-Stage Design**](workflow-patterns/three-stage-design.md) | "How to structure?" | Separate discovery, execution, reporting |
| Workflow | [**Matrix Distribution**](workflow-patterns/matrix-distribution/index.md) | "How to parallelize?" | Dynamic matrix strategies |

---

## Available Patterns

### [Idempotency](idempotency/index.md)

Build automation that survives reruns. When workflows fail mid-execution, idempotent operations let you click "rerun" without fear of duplicates, corruption, or cascading failures.

!!! tip "Start Here If..."

    - Your workflows create duplicate PRs on rerun
    - You manually clean up state after failed jobs
    - You're afraid to rerun scheduled automation

### [Work Avoidance](work-avoidance/index.md)

Detect when work isn't needed and skip it entirely. Unlike idempotency (which makes reruns safe), work avoidance prevents the run from happening at all—saving compute, API calls, and developer attention.

!!! tip "Start Here If..."

    - Your automation creates noise (version-only PRs, redundant builds)
    - You want to skip operations when nothing meaningful changed
    - You need to filter out volatile metadata before comparing

### [Graceful Degradation](graceful-degradation/index.md)

When the fast path fails, fall back to progressively slower but more reliable alternatives. Degrade performance, not availability.

!!! tip "Start Here If..."

    - Your caches miss sometimes and break workflows
    - You want systems that survive component failures
    - You need tiered fallbacks (mount → API → rebuild)

### [Workflow Patterns](workflow-patterns/index.md)

Structural patterns for building scalable, maintainable CI/CD workflows. Learn how to separate concerns, parallelize operations, and handle complex multi-target scenarios.

!!! tip "Start Here If..."

    - Your workflows are becoming hard to maintain
    - You need to process many targets (repos, services, files)
    - You want clear observability into what happened

---

## Coming Soon

!!! info "Growing Collection"

    This section expands as patterns are documented. Upcoming topics include:

    - **Fail Fast** - Stop immediately when something is wrong
    - **Prerequisite Checks** - Validate conditions before starting work
    - **Error Handling** - Fail loudly, recover gracefully
    - **Change Detection** - Know when something actually changed
    - **Rate Limiting** - Respect API boundaries at scale
    - **State Management** - Track progress across distributed operations

    Check the [Roadmap](../../../roadmap.md) for the full list.
