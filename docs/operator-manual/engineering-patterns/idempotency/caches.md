---
title: Cache Considerations
description: >-
  The hidden challenge of idempotency: surviving cache misses.
  True idempotency means reruns work regardless of cache state.
---

# Cache Considerations

There's one thing most idempotency discussions miss: caches.

---

## The Hidden Problem

GitHub Actions caches persist between workflow runs. Your idempotent workflow might depend on cached dependencies, build artifacts, or intermediate state. What happens when:

- The cache expires mid-workflow?
- A rerun uses a different cache key?
- Cache contents become stale or corrupted?

True idempotency means surviving not just reruns, but reruns with different cache states. Your workflow that "worked fine on rerun" might fail spectacularly when the cache misses.

---

## The Cache Test

!!! question "Can You Pass This Test?"

    If you deleted all caches and reran your workflow, would it still produce the same result?

    If you're not sure, you have work to do.

---

## Common Cache Traps

### Trap 1: Assuming Cache Hits

```yaml
# Dangerous: assumes cache always hits
- uses: actions/cache@v4
  with:
    path: node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}

- run: npm test  # Fails if cache missed and npm install wasn't run
```

**Fix**: Always have a fallback:

```yaml
- uses: actions/cache@v4
  id: cache
  with:
    path: node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('package-lock.json') }}

- if: steps.cache.outputs.cache-hit != 'true'
  run: npm ci

- run: npm test  # Now works regardless of cache state
```

### Trap 2: Cache Key Drift

Cache keys that include timestamps, run numbers, or other non-deterministic values cause cache misses on rerun.

```yaml
# Bad: different key on every run
key: build-${{ github.run_number }}

# Better: deterministic key based on content
key: build-${{ hashFiles('src/**') }}
```

### Trap 3: Partial Cache Restoration

Some caches restore partial state that breaks assumptions:

- Node modules with missing platform-specific binaries
- Python venvs with stale .pyc files
- Build caches with outdated object files

---

## Strategies for Cache-Resilient Idempotency

### Strategy 1: Verify Cache Validity

Don't trust cache contents blindly:

```yaml
- uses: actions/cache@v4
  id: cache
  with:
    path: ~/.npm
    key: npm-${{ hashFiles('package-lock.json') }}

- name: Verify or rebuild
  run: |
    if ! npm ls > /dev/null 2>&1; then
      echo "Cache invalid, rebuilding"
      rm -rf node_modules
      npm ci
    fi
```

### Strategy 2: Idempotent Cache Population

Make cache population itself idempotent:

```yaml
- name: Setup with idempotent install
  run: |
    # npm ci is idempotent - always produces same result from lock file
    npm ci
```

### Strategy 3: Accept Cache Misses

Design workflows that work with or without cache:

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/registry
      target/
    key: cargo-${{ hashFiles('Cargo.lock') }}
    restore-keys: |
      cargo-  # Fallback to any cargo cache

- run: cargo build  # Works regardless - just slower on miss
```

---

## Testing Cache Resilience

1. Run workflow normally (cache populated)
2. Delete all caches for the repository
3. Rerun workflow
4. Verify same end state

If step 4 fails, your idempotency depends on cache state.

---

!!! info "Deep Dive Coming"

    Cache-resilient idempotency deserves its own comprehensive guide. Check the [Roadmap](../../../roadmap.md) for upcoming content on this topic.
