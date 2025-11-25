---
title: Permission Patterns
description: >-
  Common GitHub App permission configurations for automation scenarios.
  Read-only, standard, and full automation patterns with decision tree.
---

# Permission Design Patterns

Common permission configurations for different automation scenarios.

## Read-Only Automation

For reporting and analysis workflows:

```text
Contents: Read
Pull Requests: Read
Issues: Read
Members: Read
```

!!! example "Use Cases"

    - Security scanning
    - Metrics collection
    - Compliance reporting
    - Code analysis

## Standard Automation

For typical cross-repository workflows:

```text
Contents: Read & Write
Pull Requests: Read & Write
Members: Read
```

!!! example "Use Cases"

    - File synchronization
    - Automated PR creation
    - Documentation updates
    - Dependency updates

## Full Automation

For infrastructure and repository management:

```text
Contents: Read & Write
Pull Requests: Read & Write
Administration: Write
Actions: Read & Write
Members: Read
```

!!! example "Use Cases"

    - Repository provisioning
    - Advanced CI/CD
    - Organization management
    - Template enforcement

## Permission Matrix

| Permission | Read-Only | Standard | Full |
|------------|:---------:|:--------:|:----:|
| Contents | Read | Read & Write | Read & Write |
| Pull Requests | Read | Read & Write | Read & Write |
| Issues | Read | - | Read & Write |
| Members | Read | Read | Read |
| Administration | - | - | Write |
| Actions | - | - | Read & Write |
| Workflows | - | - | Write |

## Permission Decision Tree

```mermaid
flowchart LR
    A[What does your automation need?] --> B{Create/modify repos?}
    B -->|Yes| C[Full Automation]
    B -->|No| D{Create PRs or push code?}
    D -->|Yes| E[Standard Automation]
    D -->|No| F[Read-Only Automation]

    %% Ghostty Hardcore Theme
    style A fill:#515354,stroke:#ccccc7,stroke-width:2px
    style B fill:#fd971e,stroke:#e6db74,stroke-width:2px
    style C fill:#f92572,stroke:#ff669d,stroke-width:2px
    style D fill:#65d9ef,stroke:#a3babf,stroke-width:2px
    style E fill:#9e6ffe,stroke:#9e6ffe,stroke-width:2px
    style F fill:#a7e22e,stroke:#bded5f,stroke-width:2px
```

## Pattern Guidelines

!!! tip "Start Minimal"

    Begin with Read-Only and add permissions as needed.

!!! warning "Avoid Over-Provisioning"

    Full Automation should be reserved for infrastructure workflows only.

## Next Steps

- [Security best practices](security-best-practices.md)
- [Common permission requirements](common-permissions.md)
