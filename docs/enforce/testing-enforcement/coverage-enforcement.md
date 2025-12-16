# Test Coverage Enforcement

Single-source-of-truth threshold management with Codecov, CI enforcement, and pre-commit hooks.

!!! tip "Coverage vs Enforcement"
    High coverage comes from testable code (see [Coverage Patterns](coverage-patterns.md)). This guide focuses on **enforcing** coverage thresholds consistently across environments.

---

## Single Source of Truth: codecov.yml

Both CI and pre-commit hooks read from `codecov.yml` to prevent threshold drift.

### codecov.yml Configuration

```yaml
coverage:
  status:
    project:
      default:
        target: 95%
        threshold: 0.5%
    patch:
      default:
        target: 95%
        threshold: 0.5%

comment:
  layout: "reach,diff,flags,tree"
  behavior: default
  require_changes: false
```

**Why This Matters**: One definition, zero drift. Changing the threshold updates CI, pre-commit, and Codecov reporting simultaneously.

---

## CI Integration

Extract threshold from `codecov.yml` and enforce in GitHub Actions:

```yaml
- name: Test Coverage
  run: |
    THRESHOLD=$(grep -A2 "project:" codecov.yml | grep "target:" | head -1 | sed "s/.*target: *\([0-9]*\).*/\1/")
    gotestsum --format testname -- -race -coverprofile=coverage.out -covermode=atomic ./...
    go tool cover -func=coverage.out | tail -1 | awk -v threshold="$THRESHOLD" '{
      coverage = substr($3, 1, length($3)-1);
      if (coverage < threshold) {
        print "Coverage " coverage "% is below threshold " threshold "%";
        exit 1;
      }
    }'
```

**Result**: PR fails if coverage drops below threshold defined in `codecov.yml`.

---

## Pre-Commit Hook

Prevent low-coverage commits from being created:

```bash
#!/bin/bash
# .git/hooks/pre-commit

THRESHOLD=$(grep -A2 "project:" codecov.yml | grep "target:" | head -1 | sed "s/.*target: *\([0-9]*\).*/\1/")

go test -race -coverprofile=coverage.out -covermode=atomic ./...
COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print substr($3, 1, length($3)-1)}')

if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
  echo "❌ Coverage $COVERAGE% is below threshold $THRESHOLD%"
  exit 1
fi

echo "✅ Coverage $COVERAGE% meets threshold $THRESHOLD%"
```

**Benefit**: Catch coverage drops before they reach CI.

!!! warning "Pre-Commit vs CI"
    Pre-commit hooks are local and can be bypassed with `--no-verify`. CI is the authoritative enforcement point. Pre-commit is developer convenience, not security.

---

## Component-Based Coverage

Track coverage per package to identify weak areas:

```bash
$ go test -coverprofile=coverage.out ./...
$ go tool cover -func=coverage.out

cmd/readability/main.go:45:     run             97.5%
pkg/analyzer/analyzer.go:23:    Analyze         99.1%
pkg/config/config.go:15:        LoadConfig      100.0%
pkg/markdown/parser.go:78:      Parse           98.8%
pkg/output/formatter.go:34:     Format          99.6%
total:                          (statements)    99.0%
```

Focus refactoring on packages below threshold.

### Package-Level Thresholds

For projects with legacy code, use package-level thresholds:

```yaml
# codecov.yml
coverage:
  status:
    project:
      default:
        target: 95%
    patch:
      default:
        target: 95%

  # Package-level overrides
  paths:
    cmd/readability:
      target: 97%
    pkg/analyzer:
      target: 99%
    pkg/legacy:
      target: 70%  # Temporary - improve over time
```

**Progressive Improvement**: Allow lower coverage for legacy code while enforcing high coverage for new code.

---

## Codecov Test Analytics

Enable test timing and failure tracking:

```yaml
- name: Upload Test Results
  uses: codecov/test-results-action@v1
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
```

### Benefits

- **Flaky test detection**: Identify tests with intermittent failures
- **Performance regression**: Track test execution time trends
- **Failure patterns**: See which tests fail together

!!! example "Flaky Test Detection"
    Test Analytics automatically flags tests that fail <100% of the time. If a test passes 95% of runs, it's flaky and needs investigation.

---

## OpenSSF Criteria

High coverage with proper enforcement satisfies multiple OpenSSF Best Practices requirements:

- **95%+ coverage** with branch coverage enabled
- **Race detector** enabled (`-race` flag in tests)
- **CI enforcement** (fails PR on coverage drop)
- **Pre-commit enforcement** (prevents low-coverage commits)

See: [OpenSSF Best Practices Badge](../../blog/posts/2025-12-17-openssf-badge-two-hours.md)

---

## Troubleshooting

### Error: "No coverage.out file found"

**Cause**: Tests not generating coverage file

**Fix**: Ensure `-coverprofile=coverage.out` flag in test command

### Error: "bc: command not found" (macOS)

**Cause**: Pre-commit hook uses `bc` for floating-point comparison

**Fix**: Install bc: `brew install bc`

### Error: "Codecov upload fails with 401"

**Cause**: Missing or invalid `CODECOV_TOKEN`

**Fix**: Ensure token is set in repository secrets:

```yaml
- uses: codecov/codecov-action@v4
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
    files: ./coverage.out
```

---

## Anti-Patterns

### ❌ Hardcoded Thresholds in CI

```yaml
# BAD - threshold defined in workflow
- run: |
    COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print substr($3, 1, length($3)-1)}')
    if [ "$COVERAGE" -lt 95 ]; then
      exit 1
    fi
```

**Problem**: Threshold drift when pre-commit uses different value.

### ✅ Single Source of Truth

```yaml
# GOOD - threshold from codecov.yml
- run: |
    THRESHOLD=$(grep -A2 "project:" codecov.yml | grep "target:" | head -1 | sed "s/.*target: *\([0-9]*\).*/\1/")
    COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print substr($3, 1, length($3)-1)}')
    if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
      exit 1
    fi
```

**Benefit**: One change updates all enforcement points.

---

## Related Patterns

- [Coverage Patterns](coverage-patterns.md) - Refactoring for testability
- [OpenSSF Best Practices Badge](../../blog/posts/2025-12-17-openssf-badge-two-hours.md) - Coverage requirements
- [Always Works QA](../../blog/posts/2025-12-08-always-works-qa-methodology.md) - Coverage as quality gate

---

*Enforcement without drift: one threshold definition, multiple enforcement points, zero manual synchronization.*
