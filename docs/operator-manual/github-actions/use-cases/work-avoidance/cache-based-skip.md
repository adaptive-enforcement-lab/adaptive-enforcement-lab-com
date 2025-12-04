# Cache-Based Skip

Skip operations when output artifacts already exist.

---

!!! note "Coming Soon"

    This pattern documentation is planned. For now, see:

    - [GitHub Actions: Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows) - Dependency caching
    - [actions/cache](https://github.com/actions/cache) - Cache action documentation

---

## Overview

Cache-based skip uses artifact existence as a proxy for "work already done":

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

---

## Related

- [Work Avoidance Patterns](index.md) - Pattern overview
- [Performance Optimization](../../actions-integration/performance-optimization.md) - Caching strategies
