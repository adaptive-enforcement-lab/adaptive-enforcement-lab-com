---
title: Shipping a GitHub Action the Right Way
date: 2025-12-06
authors:
  - mark
categories:
  - GitHub Actions
  - Release Engineering
  - Open Source
slug: shipping-a-github-action-the-right-way
description: >-
  Publishing a GitHub Action with versioned docs, automated releases, and proper change detection. Here's the pattern.
provenance: human
---
# Shipping a GitHub Action the Right Way

I just published [readability](https://github.com/adaptive-enforcement-lab/readability), a GitHub Action that checks docs. But this post isn't about metrics. It's about the release system that makes shipping easy.

<!-- more -->

---

## The Problem

!!! warning "The Reality"
    Most GitHub Actions ship without a real release system. Every release becomes a manual checklist.

Most GitHub Actions ship without a real release system:

- No versioned docs that match releases
- No changelog
- Manual tagging
- Builds that run when nothing changed

When you maintain many actions, this adds up. Every release becomes a checklist.

---

## The Solution: Unified Release Pipeline

One workflow handles everything:

- `release-please`: creates release PRs, bumps versions, generates changelogs
- `detect-changes`: determines what actually changed
- `build-go`: cross-compiles binaries (only on release)
- `upload-release-assets`: attaches binaries to the GitHub release
- `build-docs`: deploys versioned docs with mike

The [pipeline integration guide](../../build/versioned-docs/pipeline-integration.md) has the complete workflow.

The key insight: **run jobs only when needed**. Most pushes don't need binary builds. But docs-only changes still need the `dev` docs updated.

---

## Change Detection

`tj-actions/changed-files@v45` gets two file groups: `docs` (`docs/**`, `mkdocs.yml`) and `go` (`**.go`, `go.mod`, `go.sum`).

This outputs `docs_any_changed` and `go_any_changed` for downstream jobs to consume.

---

## Versioned Documentation with Mike

The build-docs job makes a key decision:

Did release-please create a release? Then `mike deploy --push --update-aliases` runs. If not, `mike deploy --push dev`.
The [pipeline integration guide](../../build/versioned-docs/pipeline-integration.md) has both steps.

On release: deploy `1.2.3` with aliases `v1` and `latest`.
On regular push: update `dev` only.

Users linking to `/v1/` always get the latest 1.x docs. Users on `/dev/` see the bleeding edge.

---

## Release-Please Configuration

The root package uses `release-type: go`, with `include-v-in-tag: true` and no component in the tag.
The [pipeline integration guide](../../build/versioned-docs/pipeline-integration.md) has the config.

Commits drive the release. `feat:` bumps minor. `fix:` bumps patch. `feat!:` bumps major.

---

## The Result

!!! success "Zero Manual Steps"
    Push, merge, release. Everything else is automated.

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

The readability action is at [adaptive-enforcement-lab/readability](https://github.com/adaptive-enforcement-lab/readability) with docs at [readability.adaptive-enforcement-lab.com](https://readability.adaptive-enforcement-lab.com). The workflow pattern is documented at [Versioned Documentation](../../build/versioned-docs/index.md).

---

## Related

- **[How to Harden Your SDLC Before the Audit Comes](2025-12-12-harden-sdlc-before-audit.md)** - Security automation patterns for compliance
- [Building GitHub Actions in Go](2025-12-09-building-github-actions-in-go.md) - The technical implementation guide
- [Pre-commit Hooks with Binary Releases](2025-12-10-pre-commit-hooks-binary-releases.md) - Same patterns for pre-commit
- [CLI UX Patterns for AI Agents](2025-12-07-cli-ux-patterns-for-ai-agents.md) - Design error messages AI can use
- [Should Work ≠ Does Work](2025-12-08-always-works-qa-methodology.md) - Always verify locally before shipping

---

*Ship actions like you ship software. Automate the boring parts.*
