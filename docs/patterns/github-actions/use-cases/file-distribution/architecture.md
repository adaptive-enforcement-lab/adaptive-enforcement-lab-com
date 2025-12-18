---
title: Architecture
description: >-
  Three-stage workflow architecture for file distribution: discovery via GraphQL, parallel matrix distribution, and summary reporting with separation of concerns.
---

# Architecture

This workflow implements the [Three-Stage Design][three-stage] pattern
with [Matrix Distribution][matrix] for parallel processing.

!!! tip "Separation of Concerns"
    Discovery finds targets. Distribution processes them in parallel. Summary reports results. Each stage has a single responsibility.

[three-stage]: ../../../../patterns/architecture/three-stage-design.md
[matrix]: ../../../../patterns/architecture/matrix-distribution/index.md

## Workflow Overview

```mermaid
graph TB
    A[File Changed] -->|Trigger| B[Stage 1: Discovery]
    B -->|GraphQL| C[Query Team Repos]
    C -->|JSON Array| D[Stage 2: Distribution]
    D -->|Matrix| E[Parallel Jobs]
    E --> F1[Target Repo 1]
    E --> F2[Target Repo 2]
    E --> F3[Target Repo N]
    F1 --> G[Create/Update PR]
    F2 --> G
    F3 --> G
    G --> H[Stage 3: Summary]
    H --> I[Display Results]

    %% Ghostty Hardcore Theme
    style A fill:#fd971e,color:#1b1d1e
    style B fill:#65d9ef,color:#1b1d1e
    style C fill:#9e6ffe,color:#1b1d1e
    style D fill:#65d9ef,color:#1b1d1e
    style E fill:#a7e22e,color:#1b1d1e
    style F1 fill:#5e7175,color:#f8f8f3
    style F2 fill:#5e7175,color:#f8f8f3
    style F3 fill:#5e7175,color:#f8f8f3
    style G fill:#a7e22e,color:#1b1d1e
    style H fill:#65d9ef,color:#1b1d1e
    style I fill:#9e6ffe,color:#1b1d1e
```

## Stage Summary

| Stage | Purpose | Implementation |
| ----- | ------- | -------------- |
| [Discovery](discovery-stage.md) | Find target repositories via GraphQL | Query team membership |
| [Distribution](distribution-stage.md) | Copy files and create PRs in parallel | Matrix strategy |
| [Summary](summary-stage.md) | Report results | Workflow step summary |

## Applied Patterns

This workflow demonstrates several patterns from the [Developer Guide][dev-guide]:

| Pattern | Application |
| ------- | ----------- |
| [Three-Stage Design][three-stage] | Separates discovery, execution, and reporting |
| [Matrix Distribution][matrix] | Parallelizes file distribution across repos |
| [Idempotency][idempotency] | Makes reruns safe with change detection |

[dev-guide]: ../../../../patterns/index.md
[idempotency]: ../../../../patterns/efficiency/idempotency/index.md

## Key Configuration

```yaml
strategy:
  matrix:
    repo: ${{ fromJson(needs.discover.outputs.repositories) }}
  fail-fast: false   # Continue if individual repos fail
  max-parallel: 10   # Respect API rate limits
```

For detailed implementation of each stage, see the stage-specific pages.
