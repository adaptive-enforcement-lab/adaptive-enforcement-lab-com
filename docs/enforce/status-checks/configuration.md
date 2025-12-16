---
title: Status Check Configuration Patterns
description: >-
  Configure required vs optional checks, handle flaky tests, optimize check timing,
  and manage check names for reliable CI/CD gating.
---

# Status Check Configuration Patterns

## Required vs Optional Checks

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

### Required Checks

Block merge if they fail:

- Unit tests
- Integration tests
- Security scans (HIGH/CRITICAL)
- Linting

Configure in branch protection.

### Optional Checks

Provide information but don't block:

- Performance benchmarks
- Code coverage reports
- Dependency updates

Run in workflow but don't add to `required_status_checks`.

---

## Handling Flaky Tests

Flaky tests that fail randomly undermine trust.

### Pattern 1: Retry Failed Tests

```yaml
- name: Run tests
  uses: nick-fields/retry@v2
  with:
    timeout_minutes: 10
    max_attempts: 3
    command: go test ./...
```

Genuine failures fail three times. Flakes eventually pass.

### Pattern 2: Quarantine Flaky Tests

```go
func TestFlakyBehavior(t *testing.T) {
    if testing.Short() {
        t.Skip("Flaky test - quarantined")
    }
    // Test code
}
```

Run with `go test -short` to skip quarantined tests.

Schedule separate job for quarantined tests:

```yaml
quarantine-tests:
  if: github.event_name == 'schedule'  # Nightly
  runs-on: ubuntu-latest
  steps:
    - name: Run quarantined tests
      run: go test ./... -run TestFlaky
```

Don't let flakes block development. Isolate and fix separately.

---

## Check Timing Strategies

### Parallel Execution

```yaml
jobs:
  tests:
    # Runs in parallel with security-scan and lint
  security-scan:
    # Runs in parallel
  lint:
    # Runs in parallel
```

Default: All jobs run concurrently. Fastest feedback.

### Sequential Execution

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    # Runs first

  tests:
    needs: lint  # Waits for lint
    runs-on: ubuntu-latest

  security:
    needs: tests  # Waits for tests
    runs-on: ubuntu-latest
```

Use when later checks depend on earlier results.

### Fast-Fail Strategy

```yaml
jobs:
  quick-checks:
    # Lint and format (30 seconds)

  tests:
    needs: quick-checks  # Only runs if quick checks pass
    # Tests (5 minutes)

  security:
    needs: tests  # Only runs if tests pass
    # Security scan (10 minutes)
```

Fails fast on cheap checks. Saves expensive check time.

---

## Status Check Names

GitHub matches check names exactly. Be consistent:

```yaml
# Good - consistent naming
name: CI
jobs:
  tests:
    name: tests  # Branch protection requires "tests"
```

```yaml
# Bad - name mismatch
name: CI
jobs:
  test-suite:
    name: test-suite  # Branch protection expects "tests" - FAILS
```

Verify with:

```bash
gh api repos/org/repo/commits/abc123/check-runs \
  --jq '.check_runs[].name'
```

---

## Dynamic Required Checks

Different branches may need different checks:

```yaml
# Require basic checks on all branches
required_status_checks:
  contexts:
    - "tests"
    - "lint"

# Production branches get additional checks
production_required_checks:
  contexts:
    - "tests"
    - "lint"
    - "security-scan"
    - "load-test"
```

Use GitHub API or Terraform to configure per-branch rules.

---

## Exempting Bot PRs

Dependabot or Renovate PRs may not need all checks:

```yaml
jobs:
  tests:
    # Skip tests for dependency updates
    if: github.actor != 'dependabot[bot]'
```

Better approach: Let checks run but don't require manual review:

```yaml
# Branch protection
required_pull_request_reviews:
  required_approving_review_count: 1
  bypass_pull_request_allowances:
    apps: ["dependabot"]
```

Checks still run. Bot PRs auto-merge if checks pass.

---

## Related Patterns

- **[Core Concepts](index.md)** - Status check fundamentals
- **[Operations Guide](operations.md)** - Debugging and evidence collection
- **[Matrix Filtering](../../patterns/github-actions/use-cases/work-avoidance/matrix-patterns/index.md)** - Optimize check execution

---

*Flaky test quarantined. Fast-fail strategy saved 8 minutes. Check names aligned. Configuration enforced.*
