---
description: >-
  Use artifact existence as work completion proxy. Cache key discipline, invalidation strategies, and validation patterns for builds, dependencies, and artifacts.
---

# Cache-Based Skip

Use artifact existence as a proxy for "work already done."

!!! tip "Cache Key Discipline"
    Include all inputs that affect the output in your cache key. Missing inputs cause stale cache hits.

---

## The Technique

If the output of an operation already exists and inputs haven't changed, skip the operation entirely.

```go
package main

import (
    "log"
    "os"
    "path/filepath"
)

func buildIfNeeded(cacheDir, sourceHash string) (string, error) {
    cachePath := filepath.Join(cacheDir, "build-"+sourceHash)

    if _, err := os.Stat(cachePath); err == nil {
        log.Println("Build cached, skipping")
        return cachePath, nil
    }

    result, err := build()
    if err != nil {
        return "", err
    }

    if err := result.Save(cachePath); err != nil {
        return "", err
    }
    return cachePath, nil
}
```

---

## When to Use

- **Build artifacts** - Compilation, bundling, image builds
- **Dependencies** - Package installation from lockfiles
- **Generated files** - Code generation, documentation builds
- **Expensive computations** - Data processing, ML training

---

## Cache Key Design

The cache key must include **all inputs** that affect the output:

```go
// BAD: Missing inputs
cacheKey := fmt.Sprintf("build-%s", version) // Ignores source changes!

// GOOD: All relevant inputs
cacheKey := fmt.Sprintf("build-%s-%s-%s", sourceHash, depsHash, configHash)
```

### Common Cache Key Components

| Component | Hash Source |
| ----------- | ------------- |
| Source code | `hashFiles('src/**')` |
| Dependencies | `hashFiles('package-lock.json')` |
| Build config | `hashFiles('webpack.config.js')` |
| Tool version | `node --version` |
| Platform | `runner.os` |

---

## Implementation Patterns

### GitHub Actions

```yaml
- name: Cache build artifacts
  id: cache
  uses: actions/cache@v4
  with:
    path: dist/
    key: build-${{ hashFiles('src/**', 'package-lock.json') }}

- name: Build
  if: steps.cache.outputs.cache-hit != 'true'
  run: npm run build
```

### OCI Layer Caching

```dockerfile
# Order matters - less-changing layers first (OCI/Containerfile)
FROM node:20-alpine

# Dependencies change less often than source
COPY package*.json ./
RUN npm ci

# Source changes more frequently
COPY src/ ./src/
RUN npm run build
```

### Make (Conceptual)

```text
# Makefile: target depends on source files
dist/bundle.js: $(shell find src -name '*.js')
    npm run build  # Only runs if any .js file changed

# Only rebuilds if sources are newer than target
build: dist/bundle.js
```

### Custom Script

```bash
#!/bin/bash
CACHE_DIR=".cache"
SOURCE_HASH=$(find src -type f -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1)
CACHE_FILE="$CACHE_DIR/build-$SOURCE_HASH.tar.gz"

if [ -f "$CACHE_FILE" ]; then
  echo "Cache hit, extracting..."
  tar -xzf "$CACHE_FILE" -C dist/
else
  echo "Cache miss, building..."
  npm run build
  tar -czf "$CACHE_FILE" dist/
fi
```

---

## Cache Invalidation

> "There are only two hard things in Computer Science: cache invalidation and naming things."

### Explicit Invalidation Triggers

```yaml
# Include version in key to force rebuild on major changes
key: build-v2-${{ hashFiles('src/**') }}
```

### Time-Based Expiry

```yaml
# Weekly cache refresh
key: build-${{ hashFiles('src/**') }}-week-${{ steps.date.outputs.week }}
```

### Conditional Invalidation

```bash
# Force rebuild on specific conditions
if [ "$FORCE_REBUILD" = "true" ] || [ ! -f "$CACHE_FILE" ]; then
  run_build
fi
```

---

## Cache Strategies

| Strategy | Pros | Cons |
| ---------- | ------ | ------ |
| **Exact match** | Simple, predictable | Cache misses on any change |
| **Prefix match** | Partial hits useful | Stale data risk |
| **Layered** | Granular invalidation | Complex key management |
| **Content-addressed** | Perfect deduplication | Hash computation overhead |

### Prefix Matching (GitHub Actions)

```yaml
- uses: actions/cache@v4
  with:
    path: node_modules/
    key: deps-${{ hashFiles('package-lock.json') }}
    restore-keys: |
      deps-
```

Falls back to older cache if exact match fails. This is useful for dependencies where partial cache is still valuable.

---

## Validating Cached Results

Caches can become corrupted or incomplete. Validate after restore:

```bash
- name: Restore cache
  id: cache
  uses: actions/cache@v4
  with:
    path: dist/
    key: build-${{ hashFiles('src/**') }}

- name: Validate cache
  if: steps.cache.outputs.cache-hit == 'true'
  id: validate
  run: |
    if [ -f "dist/bundle.js" ] && [ -s "dist/bundle.js" ]; then
      echo "valid=true" >> $GITHUB_OUTPUT
    else
      echo "valid=false" >> $GITHUB_OUTPUT
    fi

- name: Build
  if: steps.cache.outputs.cache-hit != 'true' || steps.validate.outputs.valid != 'true'
  run: npm run build
```

---

## Related

- [Content Hashing](content-hashing.md) - Hash computation for cache keys
- [Techniques Overview](index.md) - All work avoidance techniques
- [Cache-Based Skip (GitHub Actions)](../../../../patterns/github-actions/use-cases/work-avoidance/cache-based-skip.md) - CI/CD implementation
