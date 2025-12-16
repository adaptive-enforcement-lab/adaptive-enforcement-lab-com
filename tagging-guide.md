# Tagging Guide

How to add tags to documentation pages for multi-dimensional discovery.

## Quick Start

Add tags to the frontmatter at the top of any Markdown file:

```yaml
---
tags:
  - github-actions
  - automation
  - security
---

# Your Page Title

Content starts here...
```

## Tag Selection Rules

Follow these rules when choosing tags:

### 1. Technology Tags

Add technology tags for tools and platforms used:

```yaml
tags:
  - github         # GitHub platform features
  - github-actions # Workflows and automation
  - kubernetes     # K8s deployments
  - kyverno        # Kyverno policies
  - argo-workflows # Argo orchestration
  - go             # Go code examples
```

**Rule**: If the page contains code examples, configuration, or setup for a technology, add the tag.

### 2. Lifecycle Tags

Add lifecycle tags based on where this applies:

```yaml
tags:
  - development    # Local development
  - testing        # Testing strategies
  - ci-cd          # CI/CD pipelines
  - deployment     # Runtime deployment
  - monitoring     # Observability
  - operations     # Operational procedures
```

**Rule**: A page can have multiple lifecycle tags if it spans stages.

### 3. Practice Tags

Add practice tags for the approach or discipline:

```yaml
tags:
  - security           # Security controls
  - compliance         # Audit requirements
  - automation         # Automation patterns
  - policy-enforcement # Policy-as-code
  - efficiency         # Optimization
  - reliability        # Resilience
  - supply-chain       # Supply chain security
```

**Rule**: Always add **automation** if the page describes automated processes.

### 4. Audience Tags

Add audience tags for who benefits:

```yaml
tags:
  - developers      # Development teams
  - operators       # Platform/SRE teams
  - security-teams  # Security engineers
  - architects      # System designers
```

**Rule**: Add all relevant audience tags. Most pages apply to multiple roles.

### 5. Pattern Tags

Add pattern tags if describing a specific pattern:

```yaml
tags:
  - three-stage            # Discovery → Execute → Summary
  - hub-and-spoke          # Centralized distribution
  - strangler-fig          # Incremental migration
  - idempotency            # Idempotent operations
  - work-avoidance         # Skip unnecessary work
  - fail-fast              # Early error detection
  - retry-strategies       # Retry and backoff
```

**Rule**: Only add pattern tags if the page explicitly describes or demonstrates the pattern.

## Tag Examples by Section

### Secure Section Example

```yaml
---
tags:
  - security
  - github
  - automation
  - developers
  - operators
---

# GitHub Apps for Authentication

...content about setting up GitHub Apps...
```

**Why these tags**:

- **security**: GitHub Apps are more secure than PATs
- **github**: GitHub platform feature
- **automation**: Used in automated workflows
- **developers** + **operators**: Both roles use GitHub Apps

### Enforce Section Example

```yaml
---
tags:
  - policy-enforcement
  - kubernetes
  - kyverno
  - automation
  - compliance
  - operators
  - security-teams
---

# Kyverno Policy Deployment

...content about deploying policies...
```

**Why these tags**:

- **policy-enforcement**: Main topic
- **kubernetes** + **kyverno**: Technologies used
- **automation**: Automated enforcement
- **compliance**: Audit requirement
- **operators** + **security-teams**: Target audiences

### Build Section Example

```yaml
---
tags:
  - ci-cd
  - github-actions
  - automation
  - testing
  - developers
---

# Release Pipeline Setup

...content about automated releases...
```

**Why these tags**:

- **ci-cd**: Release pipeline context
- **github-actions**: Implementation technology
- **automation**: Automated releases
- **testing**: Includes test automation
- **developers**: Primary audience

### Patterns Section Example

```yaml
---
tags:
  - three-stage
  - github-actions
  - automation
  - idempotency
  - developers
  - operators
---

# Three-Stage Design Pattern

...content about Discovery → Execute → Summary...
```

**Why these tags**:

- **three-stage**: Specific pattern
- **github-actions**: Common implementation
- **automation**: Automation pattern
- **idempotency**: Design consideration
- **developers** + **operators**: Both implement this

## Tag Count Guidelines

**Minimum**: 3 tags (technology + practice + audience)

**Typical**: 5-7 tags

**Maximum**: 10 tags (more becomes noise)

## Tag Order

List tags in this order:

1. Technology tags first
2. Lifecycle tags second
3. Practice tags third
4. Audience tags fourth
5. Pattern tags last

Example:

```yaml
tags:
  # Technology
  - github-actions
  - kubernetes
  # Lifecycle
  - ci-cd
  - deployment
  # Practice
  - automation
  - security
  # Audience
  - developers
  - operators
  # Pattern
  - hub-and-spoke
```

## Common Tagging Mistakes

### ❌ Too Few Tags

```yaml
tags:
  - github-actions
```

**Problem**: Missing practice, audience, and context tags.

**Fix**:

```yaml
tags:
  - github-actions
  - automation
  - ci-cd
  - developers
```

### ❌ Wrong Abstraction Level

```yaml
tags:
  - kubernetes-deployment-yaml
  - github-actions-workflow-syntax
```

**Problem**: Too specific. Use standard taxonomy.

**Fix**:

```yaml
tags:
  - kubernetes
  - github-actions
```

### ❌ Missing Automation Tag

```yaml
tags:
  - github-actions
  - ci-cd
  - developers
```

**Problem**: GitHub Actions content without **automation** tag.

**Fix**:

```yaml
tags:
  - github-actions
  - automation
  - ci-cd
  - developers
```

### ❌ Missing Audience

```yaml
tags:
  - kyverno
  - policy-enforcement
  - automation
```

**Problem**: No audience tags.

**Fix**:

```yaml
tags:
  - kyverno
  - policy-enforcement
  - automation
  - operators
  - security-teams
```

## Testing Your Tags

After adding tags, verify:

1. **Build passes**: `mkdocs build`
2. **Tags page updates**: Check `docs/tags.md` after build
3. **Tag navigation works**: `mkdocs serve` and click tags
4. **Content discoverable**: Can you find this page via tags?

## Tag Evolution

Tags can evolve over time:

- **Add tags** when new patterns emerge
- **Rename tags** if better names found (update all pages)
- **Deprecate tags** if overlapping or unused
- **Document changes** in this guide

## Review Checklist

Before committing tagged content:

- [ ] Technology tags match tools/platforms used
- [ ] Lifecycle tags match where content applies
- [ ] **automation** tag added if describing automation
- [ ] **operations** tag added if operational content
- [ ] Audience tags include all relevant roles
- [ ] Pattern tags only if pattern explicitly described
- [ ] 3-10 tags total
- [ ] Tags in correct order
- [ ] Build succeeds

## Tag Reference

See [Tags](tags.md) for complete tag taxonomy and usage examples.
