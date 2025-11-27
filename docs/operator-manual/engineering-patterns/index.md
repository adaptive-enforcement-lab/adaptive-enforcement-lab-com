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

## Available Patterns

### [Idempotency](idempotency/index.md)

Build automation that survives reruns. When workflows fail mid-execution, idempotent operations let you click "rerun" without fear of duplicates, corruption, or cascading failures.

!!! tip "Start Here If..."

    - Your workflows create duplicate PRs on rerun
    - You manually clean up state after failed jobs
    - You're afraid to rerun scheduled automation

---

## Coming Soon

!!! info "Growing Collection"

    This section expands as patterns are documented. Upcoming topics include:

    - **Error Handling** - Fail loudly, recover gracefully
    - **Change Detection** - Know when something actually changed
    - **Rate Limiting** - Respect API boundaries at scale
    - **State Management** - Track progress across distributed operations

    Check the [Roadmap](../../roadmap.md) for the full list.
