---
title: Python (PyPI) Publishing
description: >-
  Implement PyPI Trusted Publishing with OIDC authentication to eliminate long-lived API tokens and generate verifiable package provenance attestations.
---
# Python (PyPI) Publishing

!!! tip "Key Insight"
    PyPI Trusted Publishing eliminates long-lived credentials in CI.

## Python (PyPI)

```yaml
name: Publish to PyPI

on:
  release:
    types: [created]

permissions: {}

jobs:
  publish:
    permissions:
      contents: read
      id-token: write  # OIDC for Trusted Publishing
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.11'

      - name: Build package
        run: |
          pip install build
          python -m build

      - uses: pypa/gh-action-pypi-publish@ec4db0b4ddc65acdf4bff5fa45ac92d78b56bdf0  # v1.9.0
        with:
          repository-url: https://upload.pypi.org/legacy/
```

**Scorecard result**: Packaging 10/10

**Note**: PyPI supports Trusted Publishing (OIDC). No long-lived tokens needed.
