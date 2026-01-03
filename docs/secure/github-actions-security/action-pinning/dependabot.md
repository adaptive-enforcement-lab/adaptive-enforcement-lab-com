---
title: Dependabot for Action Updates
description: >-
  Automated GitHub Actions updates with Dependabot. Grouping strategies, scheduling, and security-first update workflows.
tags:
  - github-actions
  - security
  - dependabot
  - automation
---

# Dependabot for Action Updates

Automate SHA pin updates. Manual updates don't scale.

!!! tip "The Pattern"

    Configure Dependabot, group related updates, review and merge, keep pins current.

## Why Dependabot for Actions

SHA pinning protects against supply chain attacks. But pinned actions go stale. Dependabot bridges the gap:

- Monitors workflow files for action updates
- Resolves tags to SHAs automatically
- Creates PRs with version comments
- Groups related updates for efficient review

**Result**: Immutable pins with continuous updates.

## Basic Configuration

### Minimal Setup

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

### Recommended Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
    labels:
      - "dependencies"
      - "github-actions"
      - "security"
    commit-message:
      prefix: "deps"
    reviewers:
      - "platform-team"
    assignees:
      - "security-team"
```

## Grouping Strategies

Without grouping, Dependabot creates separate PRs for each action. Ten actions = ten PRs.

**Solution**: Group related actions.

### Group by Trust Tier

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      github-maintained:
        patterns:
          - "actions/*"
        update-types:
          - "minor"
          - "patch"

      verified-publishers:
        patterns:
          - "aws-actions/*"
          - "azure/*"
          - "google-github-actions/*"
        update-types:
          - "minor"
          - "patch"

      community-actions:
        patterns:
          - "*"
        exclude-patterns:
          - "actions/*"
          - "aws-actions/*"
          - "azure/*"
          - "google-github-actions/*"
```

**Review priority**: GitHub-maintained actions are auto-merge candidates. Verified publishers need quick review. Community actions require thorough review.

### Group by Workflow Type

```yaml
groups:
  ci-actions:
    patterns:
      - "actions/checkout"
      - "actions/setup-*"
      - "actions/cache"

  deployment-actions:
    patterns:
      - "aws-actions/*"
      - "azure/*"

  security-actions:
    patterns:
      - "github/codeql-action"
      - "aquasecurity/*"
```

**Rationale**: Review CI updates separately from deployment updates.

### Aggressive Grouping

```yaml
groups:
  all-actions:
    patterns:
      - "*"
    update-types:
      - "minor"
      - "patch"
open-pull-requests-limit: 5
```

**Effect**: Single PR for all minor/patch updates. Major versions get individual PRs.

## Update Type Filtering

### Security-Only Updates

```yaml
schedule:
  interval: "daily"
groups:
  security-fixes:
    update-types:
      - "security"
```

**Use case**: Production repositories requiring stability.

### Exclude Major Versions

```yaml
groups:
  safe-updates:
    patterns:
      - "*"
    update-types:
      - "minor"
      - "patch"
ignore:
  - dependency-name: "*"
    update-types: ["version-update:semver-major"]
```

**Rationale**: Major versions often break compatibility. Handle manually.

### Pin Specific Actions

```yaml
ignore:
  - dependency-name: "community/critical-action"
    # Pin to specific version, no updates
  - dependency-name: "actions/setup-node"
    versions: ["4.x"]
    # Ignore v4, allow v3 updates only
```

## Auto-Merge Configuration

### GitHub Auto-Merge with Protection Rules

```yaml
# .github/workflows/dependabot-auto-merge.yml
name: Dependabot Auto-Merge

on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Check if GitHub-maintained action
        id: trust
        run: |
          if gh pr view ${{ github.event.pull_request.number }} \
            --json title --jq '.title' | grep -qE 'actions/(checkout|setup-|cache|upload-artifact)'; then
            echo "trusted=true" >> $GITHUB_OUTPUT
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Auto-approve and merge
        if: steps.trust.outputs.trusted == 'true'
        run: |
          gh pr review ${{ github.event.pull_request.number }} --approve
          gh pr merge ${{ github.event.pull_request.number }} --auto --squash
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Requirements**: Branch protection enabled, required status checks configured. Auto-merges only trusted actions after CI passes.

## Review Process

When Dependabot creates PR: check action source, read changelog for breaking changes, inspect diff to verify only SHA changed, validate full 40-char SHA, ensure CI passes, then merge.

## Complete Production Example

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
    labels:
      - "dependencies"
      - "github-actions"
    reviewers:
      - "platform-team"
    assignees:
      - "security-team"
    groups:
      github-maintained:
        patterns:
          - "actions/*"
        update-types:
          - "minor"
          - "patch"
      verified-publishers:
        patterns:
          - "aws-actions/*"
          - "azure/*"
          - "google-github-actions/*"
        update-types:
          - "minor"
          - "patch"
    ignore:
      - dependency-name: "*"
        update-types: ["version-update:semver-major"]
    open-pull-requests-limit: 10
```

## Advanced Configurations

### Multi-Directory Support

```yaml
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    labels: ["main"]
  - package-ecosystem: "github-actions"
    directory: "/.github/workflows/modules"
    labels: ["modules"]
```

### Rebase and Target Branch

```yaml
updates:
  - package-ecosystem: "github-actions"
    rebase-strategy: "auto"  # auto, disabled, always
    target-branch: "develop"
```

## Troubleshooting

**Dependabot not creating PRs**: Check syntax with `yamllint .github/dependabot.yml`, enable in Settings under Security, verify write permissions, check PR limit which defaults to 5.

**Ignored dependencies creating PRs**: Pattern matching requires `update-types` or `versions`. Exact names work without filters.

## Security Best Practices

**Require CI validation**: Configure branch protection in Settings under Branches to require status checks.

**Security team review**: Add `.github/workflows/*  @security-team` to CODEOWNERS.

**Monitor activity**: Use audit log filters for Action `dependabot` and Category `pull_request`.

## Quick Reference

### Configuration Checklist

- [ ] `dependabot.yml` in `.github/`
- [ ] Schedule configured to weekly
- [ ] Grouping strategy implemented
- [ ] Branch protection enabled
- [ ] Review process established

### Common Patterns

```yaml
# Security-only
schedule:
  interval: "daily"
groups:
  security:
    update-types: ["security"]

# Trust-tier grouping
groups:
  tier1:
    patterns: ["actions/*"]
  tier2:
    patterns: ["aws-actions/*", "azure/*"]

# Exclude majors
ignore:
  - dependency-name: "*"
    update-types: ["version-update:semver-major"]
```

## Next Steps

- **[Automation Scripts](automation.md)**: Bulk update existing workflows
- **[SHA Pinning Patterns](sha-pinning.md)**: Version comment standards
- **[Action Pinning Overview](index.md)**: Supply chain threat model

## Related Patterns

- **[Third-Party Action Evaluation](../third-party-actions/index.md)**: Assess actions before approval
- **[GITHUB_TOKEN Permissions](../token-permissions/index.md)**: Review permission changes
- **[Workflow Security](../workflows/triggers.md)**: Workflow security context

---

!!! success "Dependabot Enables Continuous Security"

    SHA pins without updates become stale. Dependabot delivers both: immutable commits and continuous patches.
