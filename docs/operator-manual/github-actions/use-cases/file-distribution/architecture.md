---
title: Architecture
description: >-
  Three-stage workflow architecture for file distribution.
---

# Architecture

## Three-Stage Workflow

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

## Stage Responsibilities

1. **Discovery**: Query organization for target repositories
2. **Distribution**: Parallel distribution to each repository
3. **Summary**: Aggregate and display results

## Data Flow

| Stage | Input | Output |
|-------|-------|--------|
| Discovery | GraphQL query | JSON array of repositories |
| Distribution | Repository list | PRs created/updated |
| Summary | Workflow results | Human-readable report |

## Key Design Principles

- **Decoupled stages** - Each stage operates independently
- **Matrix parallelization** - Distribution scales horizontally
- **Fail-fast disabled** - Individual failures don't block others
- **Idempotent operations** - Safe to re-run at any point
