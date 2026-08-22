---
title: Matrix Filtering
description: >-
  Generate GitHub Actions matrix combinations from changed paths instead of running every job every time. Skip unaffected packages, services, and platforms.
---
# Matrix Filtering

Build the job matrix from what changed, not from a static list.

!!! note "Filtering vs Static Matrices"
    A static matrix runs every combination on every trigger. A filtered matrix computes its combinations from changed-package or changed-path detection first, then runs only the affected subset.

---

## The Technique

Detect which packages, services, or directories changed, then generate the matrix from that list instead of hardcoding every combination.

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
      any-changed: ${{ steps.set-matrix.outputs.any-changed }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changed packages
        id: set-matrix
        run: |
          CHANGED=$(git diff --name-only "${{ github.event.pull_request.base.sha }}" HEAD \
            | grep '^packages/' \
            | cut -d/ -f1-2 \
            | sort -u)

          if [ -z "$CHANGED" ]; then
            echo "matrix={\"include\":[]}" >> "$GITHUB_OUTPUT"
            echo "any-changed=false" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          MATRIX_JSON=$(echo "$CHANGED" | jq -R -s -c '
            split("\n") | map(select(length > 0)) | map({package: .})
            | {include: .}
          ')

          echo "matrix=$MATRIX_JSON" >> "$GITHUB_OUTPUT"
          echo "any-changed=true" >> "$GITHUB_OUTPUT"

  build:
    needs: detect-changes
    if: needs.detect-changes.outputs.any-changed == 'true'
    strategy:
      matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build ${{ matrix.package }}
        run: make -C "${{ matrix.package }}" build
```

Zero changed packages produces an empty matrix. The `build` job never starts. No wasted runners, no empty-matrix failures.

---

## When to Use

- Monorepos with independently buildable packages or services
- Multi-platform builds where only some targets are affected by a change
- Test suites that map cleanly to source directories
- Any workflow where the job count scales with repo size but most pushes touch a small fraction of it

---

## Detecting Changed Packages

### Git Diff Against Base

```bash
# Pull requests: diff against the PR base
git diff --name-only "$BASE_SHA" "$HEAD_SHA"

# Pushes: diff against the previous commit
git diff --name-only "${{ github.event.before }}" "${{ github.sha }}"
```

### dorny/paths-filter

For workflows that need named filter groups instead of raw paths:

```yaml
- uses: dorny/paths-filter@v3
  id: filter
  with:
    filters: |
      api: 'packages/api/**'
      auth: 'packages/auth/**'
      billing: 'packages/billing/**'

- name: Build matrix from filter results
  id: set-matrix
  run: |
    INCLUDE="[]"
    for pkg in api auth billing; do
      changed="${{ steps.filter.outputs[format('{0}', pkg)] }}"
      if [ "$changed" = "true" ]; then
        INCLUDE=$(echo "$INCLUDE" | jq -c --arg p "$pkg" '. + [{"package": $p}]')
      fi
    done
    echo "matrix={\"include\":$INCLUDE}" >> "$GITHUB_OUTPUT"
```

### Directory Discovery

Combine changed-path detection with directory discovery so new packages are picked up automatically:

```bash
# All packages with a Makefile, filtered to changed ones
ALL_PACKAGES=$(find packages -maxdepth 1 -name Makefile -exec dirname {} \;)
CHANGED_PACKAGES=$(git diff --name-only "$BASE_SHA" HEAD | grep '^packages/' | cut -d/ -f1-2 | sort -u)

MATRIX=$(comm -12 <(echo "$ALL_PACKAGES" | sort) <(echo "$CHANGED_PACKAGES" | sort))
```

---

## Composing with Other Techniques

Matrix filtering answers "which combinations should exist." It composes with the techniques that answer other questions:

| Technique | Question It Answers | Where It Fits |
| ----------- | ---------------------- | ---------------- |
| [Cache-Based Skip](cache-based-skip.md) | "Is the output already built?" | Applied inside each matrix job, after filtering picks the job list |
| Path filtering (`dorny/paths-filter`) | "Did this path change?" | Feeds the changed-package list that matrix filtering consumes |
| Content hashing | "Did the content actually change?" | Validates a detected change isn't a no-op (whitespace, formatting) before it earns a matrix entry |
| [Existence Checks](existence-checks.md) | "Does the target resource exist?" | Guards downstream steps inside a filtered job, e.g. skip a deploy step if the target environment doesn't exist |

A typical layered pipeline: path filtering detects candidate changes, content hashing confirms they're meaningful, matrix filtering turns the confirmed set into job combinations, and cache-based skip avoids rebuilding within each surviving job.

---

## Anti-Patterns

### Over-Filtering Hides Real Changes

Filtering on too narrow a path pattern can silently drop jobs that should run:

```bash
# BAD: only catches direct package changes
grep '^packages/[^/]*/src/'

# A change to packages/api/package.json (a dependency bump)
# never matches, so the api package never gets rebuilt
```

Include manifest and config files, not just source directories:

```bash
# BETTER: catches source, manifests, and config
grep -E '^packages/[^/]+/(src/|package\.json|Makefile)'
```

### Ignoring Shared Dependencies

A change to a shared library used by five packages should expand the matrix to all five, not just the library's own directory:

```yaml
# BAD: shared/ changes don't trigger dependent package builds
filters: |
  api: 'packages/api/**'
  shared: 'packages/shared/**'

# BETTER: dependents rebuild when their dependency changes
filters: |
  api: 'packages/api/**, packages/shared/**'
  auth: 'packages/auth/**, packages/shared/**'
```

### Trusting an Empty Matrix Without Checking Why

An empty matrix is correct when nothing changed. It's a bug when the detection step failed silently:

```bash
# BAD: swallows errors, always produces a matrix (possibly empty)
CHANGED=$(git diff --name-only "$BASE_SHA" HEAD 2>/dev/null || echo "")

# BETTER: fail the workflow if the diff itself fails
CHANGED=$(git diff --name-only "$BASE_SHA" HEAD) || {
  echo "::error::failed to compute changed files" >&2
  exit 1
}
```

Validate the detection step's exit code before trusting a zero-job matrix. A silently empty matrix looks identical to "nothing changed" and to "detection is broken."

---

## Related

- [Cache-Based Skip](cache-based-skip.md) - Skip rebuilds within a filtered job
- [Existence Checks](existence-checks.md) - Guard downstream steps in a filtered job
- [Techniques Overview](index.md) - All work avoidance techniques
- [Matrix Filtering and Deduplication (GitHub Actions)](../../../../patterns/github-actions/use-cases/work-avoidance/matrix-patterns/index.md) - Full CI/CD implementation reference
