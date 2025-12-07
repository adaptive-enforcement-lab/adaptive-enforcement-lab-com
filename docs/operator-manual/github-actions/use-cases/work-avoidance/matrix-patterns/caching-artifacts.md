---
title: Caching and Artifact Patterns
description: >-
  Skip work already done. Track dependency changes, cache build outputs, and share
  artifacts across jobs to avoid redundant computation.
---

# Caching and Artifact Patterns

Three techniques avoid redundant work: skip expensive operations when dependencies haven't changed, cache deterministic build outputs, and build once then reuse artifacts across test jobs.

!!! tip "Performance Optimization"
    These patterns reduce workflow execution time and cost. Combine multiple techniques for maximum efficiency.

---

## Pattern 7: Skipping Unchanged Dependencies

Track dependency changes:

```yaml
jobs:
  check-deps:
    runs-on: ubuntu-latest
    outputs:
      go-mod-changed: ${{ steps.filter.outputs.go-mod }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            go-mod:
              - '**/go.mod'
              - '**/go.sum'

  vendor:
    needs: check-deps
    if: needs.check-deps.outputs.go-mod-changed == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Vendor dependencies
        run: go mod vendor
```

Skip expensive vendor operations if dependencies didn't change.

### Language-Specific Dependency Files

```yaml
filters: |
  go-deps:
    - '**/go.mod'
    - '**/go.sum'

  node-deps:
    - '**/package.json'
    - '**/package-lock.json'

  python-deps:
    - '**/requirements.txt'
    - '**/poetry.lock'

  rust-deps:
    - '**/Cargo.toml'
    - '**/Cargo.lock'
```

**Use when:** Dependency installation is expensive (npm install takes 3+ minutes).

---

## Pattern 9: Caching Matrix Outputs

Avoid rebuilding identical artifacts:

```yaml
jobs:
  build:
    strategy:
      matrix:
        arch: [amd64, arm64]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Check cache
        id: cache
        uses: actions/cache@v4
        with:
          path: dist/binary-${{ matrix.arch }}
          key: build-${{ matrix.arch }}-${{ hashFiles('**/*.go') }}

      - name: Build
        if: steps.cache.outputs.cache-hit != 'true'
        run: |
          GOARCH=${{ matrix.arch }} go build -o dist/binary-${{ matrix.arch }}
```

**How it works:**

First run:

- `hashFiles('**/*.go')` = `abc123`
- Key = `build-amd64-abc123`
- Cache miss, build runs
- Binary cached with key

Second run (unchanged source):

- `hashFiles('**/*.go')` = `abc123` (same hash)
- Key = `build-amd64-abc123` (same key)
- Cache hit, build skipped

Third run (changed source):

- `hashFiles('**/*.go')` = `def456` (different hash)
- Key = `build-amd64-def456` (new key)
- Cache miss, build runs

**Cache key strategies:**

```yaml
# OS-specific cache
key: ${{ runner.os }}-build-${{ hashFiles('**/go.sum') }}

# Restore from previous version if exact match fails
restore-keys: |
  ${{ runner.os }}-build-

# Multiple hash inputs
key: build-${{ hashFiles('go.sum') }}-${{ hashFiles('Makefile') }}
```

**Use when:** Deterministic builds, unchanged source = identical output.

---

## Pattern 10: Work Avoidance with Artifacts

One job builds, many jobs test:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build binary
        run: make build
      - uses: actions/upload-artifact@v4
        with:
          name: app-binary
          path: dist/app

  test:
    needs: build
    strategy:
      matrix:
        suite: [unit, integration, e2e]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: app-binary
          path: dist/
      - name: Run ${{ matrix.suite }} tests
        run: make test-${{ matrix.suite }}
```

**Workflow:**

1. `build` job: Compile once
2. Upload artifact (available to all jobs in workflow)
3. `test` jobs: Download artifact, run tests in parallel

**Result:** Build once, test in parallel. Avoid rebuilding per test suite.

### Multi-Artifact Pattern

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: app-${{ matrix.platform }}
    path: dist/

# Download specific artifact
- uses: actions/download-artifact@v4
  with:
    name: app-linux
    path: dist/
```

**Use when:** Build is expensive, multiple test suites need the same artifact.

---

## Cache vs Artifacts

| Feature | Cache | Artifacts |
| --------- | ------- | ----------- |
| **Purpose** | Speed up repeated builds | Share outputs between jobs |
| **Scope** | Across workflow runs | Within single workflow run |
| **Retention** | 7 days (default) | 90 days (default) |
| **Size limit** | 10 GB per repo | 10 GB per workflow |
| **Use case** | Dependencies, build outputs | Build → test handoff |

**Cache:** `npm_modules/`, compiled binaries (cross-run optimization)

**Artifacts:** Freshly built binaries for current run's test jobs

---

## Performance Impact

### Dependency Tracking

**Before:** `go mod vendor` runs every push (2 minutes)

**After:** Runs only when `go.mod` changes (once per dependency update)

Savings: 90% of runs skip vendor step.

### Caching

**Before:** Cross-compile for 3 architectures every push (9 minutes total)

**After:** Cache hits on unchanged code (0 minutes)

Savings: 100% on cache hit (typically 80% of pushes).

### Artifacts

**Before:** Build + 5 test suites = 6 builds (30 minutes)

**After:** Build once + 5 test jobs in parallel (6 minutes: 1 build + 5 parallel tests)

Savings: 80% reduction.

---

## Related Patterns

- **[Path Filtering](path-filtering.md)** - Don't run jobs for unchanged paths
- **[Matrix Optimization](matrix-optimization.md)** - Reduce matrix job count
- **[Advanced Patterns](advanced-patterns.md)** - Combine filters with caching

---

*Dependencies unchanged. Cache hit. Vendor step skipped. Build reused from cache. Artifact shared across 5 test jobs. CI time: 6 minutes down from 30.*
