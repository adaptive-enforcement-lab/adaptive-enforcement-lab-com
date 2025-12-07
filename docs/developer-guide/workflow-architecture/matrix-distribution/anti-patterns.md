# Anti-Patterns

Common mistakes to avoid in matrix distribution workflows.

!!! danger "Production Failures"
    Each anti-pattern here has caused workflow failures in production. Learn to recognize and avoid them.

---

## Hardcoded Target Lists

```yaml
# Bad: hardcoded, doesn't scale
strategy:
  matrix:
    repo: [repo-1, repo-2, repo-3]
```

Use dynamic discovery instead.

---

## Missing Fail-Fast Disable

```yaml
# Bad: one failure stops everything
strategy:
  matrix:
    target: ${{ fromJson(needs.discover.outputs.targets) }}
  # fail-fast defaults to true!
```

Always set `fail-fast: false` for distribution workflows.

---

## Unbounded Parallelism

```yaml
# Bad: may hit rate limits
strategy:
  matrix:
    target: ${{ fromJson(needs.discover.outputs.targets) }}
  # No max-parallel limit
```

Set `max-parallel` based on API rate limits.

---

## Ignoring Empty Lists

```yaml
# Bad: creates 1 job with null matrix
distribute:
  needs: discover
  strategy:
    matrix:
      target: ${{ fromJson(needs.discover.outputs.targets) }}
```

Guard against empty lists:

```yaml
distribute:
  needs: discover
  if: needs.discover.outputs.count > 0  # Skip if no targets
  strategy:
    matrix:
      target: ${{ fromJson(needs.discover.outputs.targets) }}
```

---

## Correct Pattern

```yaml
distribute:
  needs: discover
  if: needs.discover.outputs.count > 0
  strategy:
    matrix:
      target: ${{ fromJson(needs.discover.outputs.targets) }}
    fail-fast: false
    max-parallel: 10
  steps:
    - run: echo "Processing ${{ matrix.target.name }}"
```

---

## Related

- [Matrix Distribution Overview](index.md) - Core pattern
- [Three-Stage Design](../three-stage-design.md) - Workflow architecture
