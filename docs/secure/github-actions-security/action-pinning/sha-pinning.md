---
title: SHA Pinning Patterns
description: >-
  Copy-paste ready SHA pinning patterns with comment annotations for version tracking. Complete workflow examples demonstrating action pinning best practices.
tags:
  - github-actions
  - security
  - action-pinning
  - supply-chain
---

# SHA Pinning Patterns

Copy-paste ready patterns for SHA-pinned actions. Every workflow should pin third-party actions to immutable commit hashes.

!!! tip "The Pattern"

    Pin action to full SHA-256 commit hash. Add version comment for human readability. Update via Dependabot PRs.

## Basic Pattern

### Single Action Pinning

```yaml
# BEFORE: Tag reference (mutable, insecure)
- uses: actions/checkout@v4

# AFTER: SHA pinning (immutable, secure)
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

**Comment Format**: `# v<version>` on the same line as the action reference.

**Why**: The SHA is unreadable to humans. Version comments provide context without compromising security.

### Multiple Actions in Workflow

```yaml
name: Secure CI
on: [push, pull_request]

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      # Pin every third-party action to SHA
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
      - uses: actions/cache@704facf57e6136b1bc63b828d79edcd491f0ee84  # v3.3.2

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test
```

## Complete Workflow Examples

### CI/Test Workflow

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Set up Node.js
        uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run linter
        run: npm run lint

      - name: Run tests
        run: npm test

      - name: Upload coverage
        uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
```

### Deployment Workflow with OIDC

```yaml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  id-token: write  # Required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@010d0da01d0b5a38af31e9c3470dbfdabdecca3a  # v4.0.1
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-deploy
          aws-region: us-east-1

      - name: Deploy to S3
        run: |
          aws s3 sync ./dist s3://my-bucket --delete
```

## Version Comment Patterns

### Standard Format

```yaml
# Format: actions/<action>@<sha>  # v<version>
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

### Extended Format with Purpose

```yaml
# For complex workflows, include purpose in comment
- uses: aws-actions/configure-aws-credentials@010d0da01d0b5a38af31e9c3470dbfdabdecca3a  # v4.0.1 OIDC auth

- uses: docker/build-push-action@4a13e500e55cf31b7a5d59a38ab2040ab0f42f56  # v5.1.0 Build container

- uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1 Upload coverage
```

### Date-Based Comments

```yaml
# Include update date for audit tracking
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1 updated 2024-01-15
```

## Trust Tier Pinning Strategies

### Tier 1: GitHub-Maintained Actions

```yaml
# GitHub-maintained actions with standard comment
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
- uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
- uses: actions/upload-artifact@26f96dfa697d77e81fd5907df203aa23a56210a8  # v4.3.0
```

**Review Priority**: Low. GitHub security team maintains these.

**Update Frequency**: Weekly or monthly via Dependabot.

### Tier 2: Verified Publishers

```yaml
# Verified publisher actions with organization context
- uses: aws-actions/configure-aws-credentials@010d0da01d0b5a38af31e9c3470dbfdabdecca3a  # v4.0.1
- uses: azure/login@8c334a195cbb38e46038007b304988d888bf676a  # v2.0.0
- uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.0
```

**Review Priority**: Medium. Corporate security teams, but external.

**Update Frequency**: Review changelog before approving Dependabot PRs.

### Tier 3: Community Actions

```yaml
# Community actions with extra scrutiny
- uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1
- uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v1
```

**Review Priority**: High. Unknown security posture.

**Update Frequency**: Manual review of source code changes before updating.

**Consideration**: Evaluate forking high-risk actions to internal repository for full control.

### Tier 4: Fork and Pin Internal Copy

```yaml
# For critical workflows, fork action to internal org
- uses: my-org/forked-deploy-action@abc123...  # Forked from community/deploy-action v2.1.0
```

**Process**:

1. Fork action to internal organization repository
2. Review source code for security issues
3. Pin workflows to forked version
4. Manually sync updates after security review

## Common Mistakes and Fixes

### Mistake 1: Short SHA

```yaml
# BAD: Short SHA can have collisions
- uses: actions/checkout@b4ffde6

# GOOD: Full SHA-256 hash
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

**Why**: Short SHAs are not guaranteed unique. Attackers could generate collision.

### Mistake 2: Missing Version Comment

```yaml
# BAD: No context for what SHA represents
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11

# GOOD: Version comment provides human context
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

**Why**: Team members need to understand what version is pinned without running `git show`.

### Mistake 3: Pinning Wrong Ref

```yaml
# BAD: Pinning to branch HEAD (mutable)
- uses: actions/checkout@main

# BAD: Pinning to tag (mutable)
- uses: actions/checkout@v4

# GOOD: Pinning to immutable commit SHA
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

### Mistake 4: Mixing Pinned and Unpinned

```yaml
# BAD: Inconsistent pinning strategy
steps:
  - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1 Pinned
  - uses: actions/setup-node@v3  # Unpinned INSECURE
  - uses: actions/cache@v3  # Unpinned INSECURE

# GOOD: All actions SHA-pinned
steps:
  - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
  - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
  - uses: actions/cache@704facf57e6136b1bc63b828d79edcd491f0ee84  # v3.3.2
```

**Why**: Single unpinned action compromises entire workflow security.

## Container and Composite Actions

### Docker Container Actions

```yaml
# BAD: Mutable tag
- uses: docker://alpine:latest

# BETTER: Specific version tag
- uses: docker://alpine:3.18

# BEST: Digest pin
- uses: docker://alpine@sha256:7144f7bab3d4c2648d7e59409f15ec52a18006a128c733fcff20d3a4a54ba44a
```

### Composite Actions

```yaml
# Composite action reference with SHA pin
- uses: my-org/composite-action@a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0  # v1.2.3
```

**Critical**: Composite actions must pin their own dependencies. Caller cannot control internal action versions.

## Quick Reference

### SHA Pinning Checklist

- [ ] All third-party actions pinned to full SHA-256 hash
- [ ] Version comments on every pinned action
- [ ] Dependabot configured for weekly action updates
- [ ] Review process established for Dependabot PRs
- [ ] High-risk workflows prioritized and migrated
- [ ] Container images pinned to digests
- [ ] Composite actions pin their own dependencies

### Comment Format Reference

```yaml
# Standard format
- uses: <action>@<sha>  # v<version>

# Extended format
- uses: <action>@<sha>  # v<version> <purpose>

# Audit format
- uses: <action>@<sha>  # v<version> updated YYYY-MM-DD
```

### Common Actions SHA Reference

| Action | Version | SHA (40 chars) |
| ------ | ------- | -------------- |
| `actions/checkout` | v4.1.1 | `b4ffde65f46336ab88eb53be808477a3936bae11` |
| `actions/setup-node` | v3.8.1 | `5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d` |
| `actions/cache` | v3.3.2 | `704facf57e6136b1bc63b828d79edcd491f0ee84` |
| `actions/upload-artifact` | v4.3.0 | `26f96dfa697d77e81fd5907df203aa23a56210a8` |
| `aws-actions/configure-aws-credentials` | v4.0.1 | `010d0da01d0b5a38af31e9c3470dbfdabdecca3a` |

**Warning**: These SHAs are examples for reference. Always resolve latest version SHAs for your workflows.

## Next Steps

Ready to automate SHA pinning?

- **[Automation Scripts](automation.md)**: Detect unpinned actions, bulk update workflows, verify pins
- **[Dependabot Configuration](dependabot.md)**: Automated action updates with security review
- **[Action Pinning Overview](index.md)**: Return to threat model and attack vectors

## Related Patterns

- **[GITHUB_TOKEN Permissions](../token-permissions/index.md)**: Minimize token scope alongside action pinning
- **[Third-Party Action Evaluation](../third-party-actions/index.md)**: Assess actions before pinning
- **[Complete Examples](../examples/ci-workflow/index.md)**: Production workflows with all patterns applied

---

!!! success "SHA Pinning Protects Supply Chain"

    Every SHA-pinned action is an immutable security boundary. Tags can move. SHAs cannot.
