# Cache-Based Skip

Skip operations when output artifacts already exist.

!!! tip "Hash-Based Cache Keys"
    Derive cache keys from source file hashes. Same source = same output = skip the build.

This implements the [cache-based skip](../../../../patterns/efficiency/work-avoidance/techniques/cache-based-skip.md) technique for GitHub Actions workflows.

---

## Implementation

```yaml
- name: Check cache
  id: cache
  uses: actions/cache@v4
  with:
    path: dist/
    key: build-${{ hashFiles('src/**') }}

- name: Build
  if: steps.cache.outputs.cache-hit != 'true'
  run: npm run build
```

The cache key is derived from source file hashes. Same source = same output = skip the build.

---

## When to Use

- **Build artifacts** - Skip compilation when source unchanged
- **Dependencies** - Skip install when lockfile unchanged
- **Generated files** - Skip generation when inputs unchanged

---

## Key Considerations

- **Cache key design** - Include all inputs that affect output
- **Cache invalidation** - Know when to bust the cache
- **Partial hits** - Handle cases where cache is stale

See the [engineering pattern](../../../../patterns/efficiency/work-avoidance/techniques/cache-based-skip.md) for conceptual details.

---

## Related

- [Work Avoidance in GitHub Actions](index.md) - Pattern overview
- [Performance Optimization](../../actions-integration/performance-optimization.md) - Caching strategies

## References

- [GitHub Actions: Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows) - Official documentation
- [actions/cache](https://github.com/actions/cache) - Cache action
