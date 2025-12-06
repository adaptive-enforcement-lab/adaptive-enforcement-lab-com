---
date: 2025-12-06
authors:
  - mark
categories:
  - DevSecOps
  - GitHub Actions
  - Open Source
slug: shipping-a-github-action-the-right-way
description: >-
  Publishing a GitHub Action with versioned docs, automated releases, and proper change detection. Here's the pattern.
---

# Shipping a GitHub Action the Right Way

I just published [readability](https://github.com/adaptive-enforcement-lab/readability), a GitHub Action that checks docs. But this post isn't about metrics. It's about the release system that makes shipping easy.

<!-- more -->

---

## The Problem

Most GitHub Actions ship without a real release system:

- No versioned docs that match releases
- No changelog
- Manual tagging
- Builds that run when nothing changed

When you maintain many actions, this adds up. Every release becomes a checklist.

---

## The Solution: Unified Release Pipeline

One workflow handles everything:

```yaml
name: Release Pipeline

on:
  push:
    branches: [main]

jobs:
  release-please:
    # Creates release PRs, bumps versions, generates changelogs

  detect-changes:
    # Determines what actually changed

  build-go:
    # Cross-compiles binaries (only on release)

  upload-release-assets:
    # Attaches binaries to GitHub release

  build-docs:
    # Deploys versioned docs with mike
```

The key insight: **run jobs only when needed**. Most pushes don't need binary builds. But docs-only changes still need the `dev` docs updated.

---

## Change Detection

```yaml
detect-changes:
  steps:
    - uses: tj-actions/changed-files@v45
      with:
        files_yaml: |
          docs:
            - docs/**
            - mkdocs.yml
          go:
            - '**.go'
            - go.mod
            - go.sum
```

This outputs `docs_any_changed` and `go_any_changed` for downstream jobs to consume.

---

## Versioned Documentation with Mike

The build-docs job makes a key decision:

```yaml
- name: Deploy versioned docs
  if: needs.release-please.outputs.release_created == 'true'
  run: |
    mike deploy --push --update-aliases \
      ${{ steps.version.outputs.version }} \
      ${{ steps.version.outputs.alias }} latest

- name: Deploy dev docs
  if: needs.release-please.outputs.release_created != 'true'
  run: mike deploy --push dev
```

On release: deploy `1.2.3` with aliases `v1` and `latest`.
On regular push: update `dev` only.

Users linking to `/v1/` always get the latest 1.x docs. Users on `/dev/` see the bleeding edge.

---

## Release-Please Configuration

```json
{
  "include-v-in-tag": true,
  "packages": {
    ".": {
      "release-type": "go",
      "component": "readability",
      "include-component-in-tag": false
    }
  }
}
```

Commits drive the release. `feat:` bumps minor. `fix:` bumps patch. `feat!:` bumps major.

---

## The Result

Push a fix to main:

1. Release-please opens a PR with changelog and version bump
2. Merge the PR
3. Release-please creates the GitHub release and tag
4. Binary builds run in parallel (5 platforms)
5. Binaries attach to the release
6. Versioned docs deploy with proper aliases

Zero manual steps. Consistent every time.

---

## What This Enables

With this infrastructure in place:

- **Version matching works** - Docs match the action version in use
- **Work ships fast** - No waiting for manual releases
- **It scales** - Same pattern across all actions

The readability action is at [adaptive-enforcement-lab/readability](https://github.com/adaptive-enforcement-lab/readability) with docs at [readability.adaptive-enforcement-lab.com](https://readability.adaptive-enforcement-lab.com). The workflow pattern is documented at [Versioned Documentation](../../operator-manual/github-actions/use-cases/versioned-docs/index.md).

---

*Ship actions like you ship software. Automate the boring parts.*
