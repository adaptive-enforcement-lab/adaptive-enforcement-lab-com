---
title: Advanced Matrix Patterns
description: >-
  Fast-fail strategies for critical vs optional checks. Combine path filters with
  dynamic matrices for maximum work avoidance.
---

# Advanced Matrix Patterns

Two advanced techniques: segregate critical checks from optional validations with fail-fast control, and combine multiple filtering strategies for maximum efficiency.

---

## Pattern 8: Fast-Fail with Required Checks

Fail fast but keep required checks:

```yaml
jobs:
  critical:
    # Always runs (required for branch protection)
    runs-on: ubuntu-latest
    steps:
      - name: Critical security scan
        run: make security-scan

  optional:
    # Runs only on specific triggers
    if: github.event_name == 'schedule'
    strategy:
      fail-fast: false  # Continue other jobs if one fails
      matrix:
        check: [performance, load-test, fuzz]
    runs-on: ubuntu-latest
    steps:
      - name: Run ${{ matrix.check }}
        run: make ${{ matrix.check }}
```

**How it works:**

- `critical` job runs every push, required for merges
- `optional` jobs run on schedule (nightly, weekly)
- `fail-fast: false` ensures all optional checks complete even if one fails

**Branch protection** requires `critical`. `optional` jobs don't block merges.

### Fail-Fast Strategies

```yaml
# Default: stop all matrix jobs if one fails
strategy:
  fail-fast: true  # default

# Continue all: useful for test matrices
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu, macos, windows]
    # Want to see failures on all OSes, not just first

# Per-job control
jobs:
  smoke-tests:
    strategy:
      fail-fast: true  # Stop fast on critical path
      matrix:
        env: [dev, staging, prod]

  compatibility-tests:
    strategy:
      fail-fast: false  # Collect all failures
      matrix:
        version: ['1.18', '1.19', '1.20', '1.21']
```

### Required vs Optional Segregation

```yaml
jobs:
  # Required: Block merges
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: make lint

  test:
    runs-on: ubuntu-latest
    steps:
      - run: make test

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - run: make security-scan

  # Optional: Don't block merges
  benchmark:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - run: make benchmark

  vulnerability-scan:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - run: make vuln-scan

  load-test:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - run: make load-test
```

**Branch protection settings:**

- Required checks: `lint`, `test`, `security-scan`
- Optional (not required): `benchmark`, `vulnerability-scan`, `load-test`

**Use when:** Critical checks must pass for merge, but expensive validations run separately.

---

## Pattern 11: Combining Filters and Matrices

Dynamic matrix + path filtering:

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
      has-changes: ${{ steps.set-matrix.outputs.has-changes }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            charts:
              - 'charts/**'
            workflows:
              - '.github/workflows/**'

      - name: Build matrix
        id: set-matrix
        run: |
          MATRIX='{"include":[]}'

          if [[ "${{ steps.filter.outputs.charts }}" == "true" ]]; then
            # Find changed charts
            CHANGED_CHARTS=$(git diff --name-only ${{ github.event.before }}..${{ github.sha }} | \
              grep '^charts/' | cut -d'/' -f2 | sort -u)

            for chart in $CHANGED_CHARTS; do
              MATRIX=$(echo "$MATRIX" | jq ".include += [{\"chart\": \"$chart\", \"task\": \"lint\"}]")
              MATRIX=$(echo "$MATRIX" | jq ".include += [{\"chart\": \"$chart\", \"task\": \"test\"}]")
            done
          fi

          HAS_CHANGES=$(echo "$MATRIX" | jq '.include | length > 0')
          echo "matrix=$MATRIX" >> $GITHUB_OUTPUT
          echo "has-changes=$HAS_CHANGES" >> $GITHUB_OUTPUT

  validate:
    needs: detect-changes
    if: needs.detect-changes.outputs.has-changes == 'true'
    strategy:
      matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: ${{ matrix.task }} ${{ matrix.chart }}
        run: make helm-${{ matrix.task }} CHART=${{ matrix.chart }}
```

**How it works:**

Changed `charts/nginx/values.yaml`:

- Path filter detects `charts/**` changed
- Git diff finds `nginx` chart modified
- Matrix generated: `[{chart: nginx, task: lint}, {chart: nginx, task: test}]`
- Runs 2 jobs instead of all charts × 2 tasks

**Multi-dimensional matrix:**

```json
{
  "include": [
    {"chart": "nginx", "task": "lint"},
    {"chart": "nginx", "task": "test"},
    {"chart": "postgres", "task": "lint"},
    {"chart": "postgres", "task": "test"}
  ]
}
```

### Advanced Combination Patterns

```yaml
# Combine path filter + conditional expansion
if [[ "${{ steps.filter.outputs.backend }}" == "true" ]]; then
  if [[ "${{ github.event_name }}" == "pull_request" ]]; then
    # PR: Full test matrix
    MATRIX=$(jq -n '{os: ["ubuntu", "macos", "windows"]}')
  else
    # Push: Fast feedback
    MATRIX=$(jq -n '{os: ["ubuntu"]}')
  fi
fi
```

### Real-World Example: Monorepo

```yaml
# Detects changed services
# Expands matrix based on event type
# Caches dependencies
# Shares build artifacts
# Fails fast on critical path

jobs:
  changes:
    outputs:
      services: ${{ steps.filter.outputs.changes }}
    steps:
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            api: 'services/api/**'
            auth: 'services/auth/**'
            billing: 'services/billing/**'

  build:
    needs: changes
    if: needs.changes.outputs.services != '[]'
    strategy:
      matrix:
        service: ${{ fromJson(needs.changes.outputs.services) }}
    steps:
      - uses: actions/cache@v4
        with:
          path: ~/.cargo
          key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}

      - run: cargo build --release
      - uses: actions/upload-artifact@v4

  test:
    needs: [changes, build]
    strategy:
      fail-fast: ${{ github.event_name == 'pull_request' }}
      matrix:
        service: ${{ fromJson(needs.changes.outputs.services) }}
        suite: [unit, integration]
    steps:
      - uses: actions/download-artifact@v4
      - run: make test-${{ matrix.suite }}
```

**Combined techniques:**

1. Path filtering (dorny/paths-filter)
2. Dynamic matrix (changed services only)
3. Caching (Cargo dependencies)
4. Artifacts (build → test handoff)
5. Conditional fail-fast (strict on PR, lenient on push)

**Use when:** Maximum work avoidance needed, monorepo, complex validation requirements.

---

## Comparison

| Pattern | Complexity | Savings | Use Case |
| --------- | ------------ | --------- | ---------- |
| **Fast-Fail** | Low | Time (fail fast) | Critical vs optional checks |
| **Combining Filters** | High | Compute + time | Monorepo with multiple dimensions |

---

## Related Patterns

- **[Path Filtering](path-filtering.md)** - Foundation for combining patterns
- **[Matrix Optimization](matrix-optimization.md)** - Deduplication and conditional expansion
- **[Caching and Artifacts](caching-artifacts.md)** - Work avoidance fundamentals

---

*Path filter detected backend changes. Dynamic matrix built 3 services. Conditional expansion ran lightweight tests on push. Caching skipped dependency install. Artifacts shared build output. Fast-fail stopped on first critical failure. Combined patterns reduced CI time 92%: 47 minutes → 4 minutes.*
