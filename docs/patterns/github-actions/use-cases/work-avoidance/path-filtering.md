# Path Filtering

Skip workflows when relevant files haven't changed.

!!! tip "Native GitHub Feature"
    Path filtering is built into GitHub Actions. No custom code required—just configure `paths` and `paths-ignore` in your workflow triggers.

---

## Native GitHub Feature

GitHub Actions provides built-in path filtering:

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'package.json'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

This is a platform feature, not a pattern implementation. See the official documentation for full syntax.

---

## When to Use

- **Monorepo builds** - Only build changed packages
- **Documentation changes** - Skip CI for doc-only PRs
- **Config changes** - Trigger only relevant pipelines

---

## Related

- [Work Avoidance in GitHub Actions](index.md) - Pattern overview
- [Change Detection](../../../../build/release-pipelines/change-detection.md) - Runtime path detection

## References

- [GitHub Actions: paths filter](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore) - Official documentation
