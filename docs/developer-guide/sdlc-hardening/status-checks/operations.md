---
title: Status Check Operations
description: >-
  Debug failed checks, collect audit evidence, and optimize CI/CD costs
  through caching, path filtering, and self-hosted runners.
---

# Status Check Operations

## Debugging Failed Checks

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

### View Check Details

```bash
# Get check run details
gh api repos/org/repo/commits/abc123/check-runs \
  --jq '.check_runs[] | {name, conclusion, output}'
```

### Re-run Failed Checks

```bash
# Re-run specific check
gh api --method POST \
  repos/org/repo/check-runs/CHECK_ID/rererun
```

### Check Status URL

Every PR shows status check URLs. Click through to workflow logs.

---

## Evidence for Auditors

Demonstrate enforcement with API queries:

```bash
# Show all PRs from March 2025 had required checks
gh api 'repos/org/repo/pulls?state=closed&base=main' \
  --jq '.[] | select(.merged_at | startswith("2025-03")) |
    {pr: .number, checks: .statuses_url}'
```

For each PR, show check results:

```bash
gh api repos/org/repo/commits/COMMIT_SHA/check-runs \
  --jq '.check_runs[] | {name, conclusion}'
```

Auditors verify all merged code passed required checks.

---

## Cost Optimization

GitHub Actions minutes cost money. Optimize checks:

### Cache Dependencies

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache/go-build
      ~/go/pkg/mod
    key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
```

### Path Filtering

```yaml
on:
  pull_request:
    paths:
      - '**.go'
      - 'go.mod'
      - 'go.sum'
```

Don't run Go tests when only markdown changed.

### Self-Hosted Runners

```yaml
runs-on: [self-hosted, linux, x64]
```

Free compute for private repos.

---

## Related Patterns

- **[Core Concepts](index.md)** - Status check fundamentals
- **[Configuration Patterns](configuration.md)** - Required vs optional checks
- **[Branch Protection](../branch-protection.md)** - Enforcement framework
- **[Zero-Vulnerability Pipelines](../../../blog/posts/2025-12-15-zero-vulnerability-pipelines.md)** - Security scanning gates
- **[Pre-commit Hooks](../pre-commit-hooks.md)** - Earlier validation
- **[Audit Evidence Collection](../audit-evidence.md)** - Comprehensive evidence gathering

---

*Required checks blocked the PR. Tests failed. Vulnerabilities found. The code didn't merge. The pipeline worked.*
