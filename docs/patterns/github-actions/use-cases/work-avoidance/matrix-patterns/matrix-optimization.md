---
title: Matrix Optimization Patterns
description: >-
  Eliminate duplicate matrix combinations with include/exclude patterns. Conditionally expand based on event type and auto-discover services from repository structure.
---

# Matrix Optimization Patterns

Three optimization techniques reduce redundant matrix jobs: deduplication with include/exclude, conditional expansion based on context, and automatic discovery from repository structure.

!!! tip "Performance Optimization"
    These patterns reduce workflow execution time and cost. Combine multiple techniques for maximum efficiency.

---

## Pattern 4: Matrix Deduplication

Eliminate duplicate matrix combinations:

### Problem: Overlapping Configurations

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest]
    go: ['1.21', '1.22']
    # 4 combinations, but we only need:
    # - ubuntu with latest Go
    # - macos with latest Go
    # - ubuntu with older Go for compatibility
```

Four jobs run, but only three are necessary.

### Solution: Include/Exclude

```yaml
strategy:
  matrix:
    os: [ubuntu-latest]
    go: ['1.21', '1.22']
    include:
      # Add macOS with latest Go only
      - os: macos-latest
        go: '1.22'
```

**Result:** 3 jobs instead of 4.

Matrix:

1. ubuntu-latest + Go 1.21
2. ubuntu-latest + Go 1.22
3. macos-latest + Go 1.22 (from include)

### Exclude Pattern

Remove specific combinations:

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, macos-latest, windows-latest]
    arch: [amd64, arm64]
    exclude:
      # Windows ARM64 runners don't exist
      - os: windows-latest
        arch: arm64
```

6 combinations → 5 jobs (Windows ARM64 excluded).

**Use when:** Some matrix combinations don't make sense or aren't supported.

---

## Pattern 5: Conditional Matrix Expansion

Expand matrix only on specific conditions:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os: ${{ github.event_name == 'push' && fromJson('["ubuntu-latest"]') || fromJson('["ubuntu-latest", "macos-latest", "windows-latest"]') }}
    runs-on: ${{ matrix.os }}
    steps:
      - name: Test
        run: make test
```

**Behavior:**

- On **push**: Test on Ubuntu only (fast feedback)
- On **pull_request**: Test on all OSes (comprehensive validation)

### Other Conditional Triggers

```yaml
# Expand on main branch
matrix:
  os: ${{ github.ref == 'refs/heads/main' && fromJson('[...]') || fromJson('[...]') }}

# Expand on tags
matrix:
  os: ${{ startsWith(github.ref, 'refs/tags/') && fromJson('[...]') || fromJson('[...]') }}

# Expand on schedule
matrix:
  os: ${{ github.event_name == 'schedule' && fromJson('[...]') || fromJson('[...]') }}
```

**Use when:** Different events require different rigor (push = fast, PR = thorough, release = exhaustive).

---

## Pattern 6: Monorepo Matrix from Directory Discovery

Generate matrix from repository structure:

```yaml
jobs:
  discover:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.discover.outputs.services }}
    steps:
      - uses: actions/checkout@v4
      - name: Discover services
        id: discover
        run: |
          # Find all directories with go.mod
          SERVICES=$(find services -name 'go.mod' -type f | \
            xargs -I {} dirname {} | \
            xargs -I {} basename {} | \
            jq -R -s -c 'split("\n") | map(select(length > 0))')

          echo "services=$SERVICES" >> $GITHUB_OUTPUT

  test:
    needs: discover
    strategy:
      matrix:
        service: ${{ fromJson(needs.discover.outputs.services) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test ${{ matrix.service }}
        run: |
          cd services/${{ matrix.service }}
          go test ./...
```

**How it works:**

Repository has:

```text
services/
  api/go.mod
  auth/go.mod
  billing/go.mod
```

Discovery finds: `["api", "auth", "billing"]`

Matrix runs 3 jobs automatically.

**New service added?** Matrix automatically includes it. No workflow changes needed.

### Discovery Patterns

```bash
# Find all Dockerfiles
find . -name 'Dockerfile' -type f

# Find all package.json
find . -name 'package.json' -type f

# Find all Chart.yaml (Helm charts)
find charts -name 'Chart.yaml' -type f

# Find all *_test.go (Go test packages)
find . -name '*_test.go' -type f
```

**Use when:** Monorepo scales beyond manual matrix maintenance.

---

## Comparison

| Pattern | Complexity | Maintenance | Use Case |
| --------- | ------------ | ------------- | ---------- |
| **Deduplication** | Low | Manual | Fixed configurations with overlap |
| **Conditional Expansion** | Medium | Manual | Different rigor per event |
| **Directory Discovery** | Medium | Automatic | Growing monorepo |

---

## Related Patterns

- **[Path Filtering](path-filtering.md)** - Filter by changed files
- **[Caching and Artifacts](caching-artifacts.md)** - Skip unchanged work
- **[Advanced Patterns](advanced-patterns.md)** - Combine with filters

---

*Matrix had 47 service combinations. Directory discovery found 3 changed services. Conditional expansion ran lightweight tests on push, full suite on PR. Deduplication removed redundant platform combinations. 47 jobs → 3 jobs.*
