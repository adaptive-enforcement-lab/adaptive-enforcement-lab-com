---
title: Path-Based Filtering Patterns
description: >-
  Run jobs only when specific files change. Static path filters, dynamic matrices,
  and Dorny paths-filter for shared dependencies.
---

# Path-Based Filtering Patterns

Three approaches to filter workflows by changed files: static path triggers, dynamic matrix generation, and declarative path filters with dependency handling.

---

## Pattern 1: Path-Based Filtering

Run jobs only when specific paths change.

### Static Path Filters

```yaml
on:
  push:
    paths:
      - 'services/api/**'
      - '.github/workflows/api.yml'

jobs:
  test-api:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test API
        run: make test-api
```

Workflow triggers only when files matching the paths change.

**Limitations:**

- Separate workflow per service (not scalable)
- Can't share common setup steps
- Hard to maintain as services grow

**Use when:** Single service, simple trigger logic.

---

## Pattern 2: Dynamic Matrix with Changed Files

Build matrix based on changed files:

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git diff

      - name: Detect changed services
        id: set-matrix
        run: |
          # Get changed files since last push
          CHANGED_FILES=$(git diff --name-only ${{ github.event.before }}..${{ github.sha }})

          # Extract service names from paths
          SERVICES=$(echo "$CHANGED_FILES" | \
            grep '^services/' | \
            cut -d'/' -f2 | \
            sort -u | \
            jq -R -s -c 'split("\n") | map(select(length > 0))')

          # Output as JSON array
          echo "matrix={\"service\":$SERVICES}" >> $GITHUB_OUTPUT

  test:
    needs: detect-changes
    if: needs.detect-changes.outputs.matrix != '{"service":[]}'
    strategy:
      matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Test ${{ matrix.service }}
        run: make test-${{ matrix.service }}
```

**How it works:**

Changed `services/api/handler.go`:

- `detect-changes` finds `api` in changed paths
- Matrix becomes `{"service": ["api"]}`
- Only 1 job runs instead of 6

**Use when:** Monorepo with many services, need dynamic scaling.

---

## Pattern 3: Dorny Paths Filter

Use `dorny/paths-filter` for cleaner change detection:

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      api: ${{ steps.filter.outputs.api }}
      auth: ${{ steps.filter.outputs.auth }}
      billing: ${{ steps.filter.outputs.billing }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            api:
              - 'services/api/**'
              - 'shared/models/**'
            auth:
              - 'services/auth/**'
              - 'shared/models/**'
            billing:
              - 'services/billing/**'
              - 'shared/payment/**'

  test-api:
    needs: changes
    if: needs.changes.outputs.api == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Test API
        run: make test-api

  test-auth:
    needs: changes
    if: needs.changes.outputs.auth == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Test Auth
        run: make test-auth
```

**Shared dependencies handled:** Change to `shared/models/` triggers both `api` and `auth`.

**Use when:** Cross-cutting dependencies, need clear filter declarations.

---

## Comparison

| Approach | Pros | Cons | Best For |
| ---------- | ------ | ------ | ---------- |
| **Static Paths** | Simple, built-in | One workflow per path | Single services |
| **Dynamic Matrix** | Flexible, scalable | More complex setup | Monorepos |
| **Dorny Filter** | Declarative, clean | External action dependency | Shared dependencies |

---

## Related Patterns

- **[Matrix Optimization](matrix-optimization.md)** - Reduce duplicate job combinations
- **[Caching and Artifacts](caching-artifacts.md)** - Skip unchanged dependencies
- **[Advanced Patterns](advanced-patterns.md)** - Combine filters for maximum efficiency

---

*Changed one file in services/api. Dynamic matrix detected the change. Only api job ran. 29 other services stayed idle. CI completed in 3 minutes instead of 45.*
