# Path Filtering

Skip jobs when relevant files haven't changed.

---

!!! note "Coming Soon"

    This pattern documentation is planned. For now, see:

    - [Change Detection](../release-pipelines/change-detection.md) - Path-based filtering for release pipelines
    - [GitHub Actions: paths filter](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore) - Native workflow filtering

---

## Overview

Path filtering skips entire jobs or workflows when changes don't affect relevant directories:

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

---

## Related

- [Work Avoidance Patterns](index.md) - Pattern overview
- [Change Detection](../release-pipelines/change-detection.md) - Monorepo change detection
