# Modular Release Pipelines

Automated version management, changelog generation, and optimized builds for monorepos.

---

## Overview

This guide covers implementing release automation with:

- **Release-please** for version bumping and changelog generation
- **Change detection** to skip unnecessary builds
- **Cascade rebuilds** when shared dependencies change
- **Dual-trigger patterns** for automation compatibility

```mermaid
flowchart LR
    subgraph triggers[Triggers]
        PR[pull_request]
        Push[push to release-please--**]
    end

    subgraph pipeline[Build Pipeline]
        DC[Detect Changes]
        Test[Test]
        Build[Build Components]
        Status[Build Status]
    end

    PR --> DC
    Push --> DC
    DC --> Test
    Test --> Build
    Build --> Status

    style PR fill:#65d9ef,color:#1b1d1e
    style Push fill:#65d9ef,color:#1b1d1e
    style DC fill:#fd971e,color:#1b1d1e
    style Test fill:#9e6ffe,color:#1b1d1e
    style Build fill:#a7e22e,color:#1b1d1e
    style Status fill:#5e7175,color:#f8f8f3
```

---

## The Problem

Traditional CI/CD pipelines rebuild everything on every commit. In a monorepo with multiple components, this means:

- Unnecessary compute time for unchanged components
- Longer feedback loops for developers
- Wasted resources on duplicate work

Additionally, conventional release management requires manual:

- Version bumping in package files
- Changelog maintenance
- Git tagging

Release-please automates this based on conventional commits, but introduces a compatibility challenge with standard `pull_request` triggers.

---

## The Solution

A modular pipeline architecture that:

1. Detects which components changed
2. Only builds affected components
3. Automatically versions and releases based on commits
4. Works with protected branches and automation tools

---

## Guides

| Guide | Description |
|-------|-------------|
| [Release-Please Configuration](release-please-setup.md) | Setting up automated versioning |
| [Change Detection](change-detection.md) | Detecting and cascading changes |
| [Workflow Triggers](workflow-triggers.md) | GITHUB_TOKEN limitations and workarounds |
| [Protected Branches](protected-branches.md) | Working with branch protection rules |

---

## Architecture

### Build Pipeline

Runs on pull requests and release-please branches:

```mermaid
flowchart TD
    subgraph detect[Change Detection]
        Contracts[Contracts Changed?]
        Backend[Backend Changed?]
        Frontend[Frontend Changed?]
        Charts[Charts Changed?]
    end

    subgraph cascade[Cascade Logic]
        BNB[Backend Needs Build]
        FNB[Frontend Needs Build]
    end

    subgraph build[Conditional Build]
        Test[Test Node Packages]
        BB[Build Backend]
        BF[Build Frontend]
        HC[Helm Charts]
    end

    Contracts -->|yes| BNB
    Contracts -->|yes| FNB
    Backend -->|yes| BNB
    Frontend -->|yes| FNB

    BNB --> Test
    FNB --> Test
    BNB --> BB
    FNB --> BF
    Charts --> HC

    style Contracts fill:#fd971e,color:#1b1d1e
    style Backend fill:#fd971e,color:#1b1d1e
    style Frontend fill:#fd971e,color:#1b1d1e
    style Charts fill:#fd971e,color:#1b1d1e
    style BNB fill:#a7e22e,color:#1b1d1e
    style FNB fill:#a7e22e,color:#1b1d1e
    style Test fill:#9e6ffe,color:#1b1d1e
    style BB fill:#a7e22e,color:#1b1d1e
    style BF fill:#a7e22e,color:#1b1d1e
    style HC fill:#bded5f,color:#1b1d1e
```

### Release Pipeline

Runs on main branch pushes:

```mermaid
flowchart LR
    Main[Push to Main] --> RP[Release Please]
    RP --> DC[Detect Changes]
    DC --> Test[Test]
    DC --> Build[Build]
    Build --> Scan[Security Scan]
    Scan --> Deploy[Deploy Signal]

    style Main fill:#65d9ef,color:#1b1d1e
    style RP fill:#9e6ffe,color:#1b1d1e
    style DC fill:#fd971e,color:#1b1d1e
    style Test fill:#9e6ffe,color:#1b1d1e
    style Build fill:#a7e22e,color:#1b1d1e
    style Scan fill:#f92572,color:#1b1d1e
    style Deploy fill:#e6db74,color:#1b1d1e
```

---

## Quick Start

1. [Configure release-please](release-please-setup.md) for your repository
2. [Set up change detection](change-detection.md) for your components
3. [Add dual triggers](workflow-triggers.md) for automation compatibility
4. [Handle protected branches](protected-branches.md) if applicable

---

## Related

- [Idempotency Patterns](../../../../developer-guide/engineering-practices/patterns/idempotency/index.md) for making reruns safe
- [Three-Stage Design](../../../../developer-guide/engineering-practices/patterns/workflow-patterns/three-stage-design.md) for complex workflows
