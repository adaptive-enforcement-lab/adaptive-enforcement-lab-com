---
title: "Go-Based GitHub Actions: From Code to Marketplace"
date: 2025-12-09
authors:
  - mark
categories:
  - Go
  - GitHub Actions
  - Release Engineering
description: >-
  Single-binary distribution, millisecond cold starts, zero runtime deps.
  Ship Go-based GitHub Actions the right way.
slug: building-github-actions-in-go
provenance: human
---
# Go-Based GitHub Actions: From Code to Marketplace

Go works well for GitHub Actions. Single binaries, fast starts, cross-platform builds, and no runtime deps.

Here's how to go from code to release.

<!-- more -->

## Why Go for GitHub Actions?

| Advantage | Impact |
| ----------- | -------- |
| Single binary | No `node_modules` or virtual env needed |
| Fast cold start | Starts in milliseconds, not seconds |
| Cross-platform | One codebase builds for Linux, macOS, Windows |
| Strong typing | Catch errors at compile time |

The trade-off is larger binary size, but caching helps.

!!! tip "Binary Distribution"
    Use composite actions with pre-built binaries. Don't make users compile from source.

---

## Project Structure

`action.yml` at the root, the CLI entrypoint under `cmd/`, business logic, config and output formatters under `pkg/`, plus build and release workflows and a `.goreleaser.yml`.
The [GitHub Actions distribution guide](../../build/go-cli-architecture/packaging/github-actions.md) has the full layout.

---

## The action.yml File

Define your action interface. Composite steps download and run the binary.

The [GitHub Actions distribution guide](../../build/go-cli-architecture/packaging/github-actions.md) has a complete `action.yml`.

---

## CLI Structure

Standard Cobra CLI with version injection.

A Cobra root command carries a `version` variable that GoReleaser sets at build time, a `--check` flag that turns failures into exit 1, and a `--config` flag.
The [release automation guide](../../build/go-cli-architecture/packaging/release-automation.md) has the code.

---

## GoReleaser Configuration

Build cross-platform binaries.

One config builds for every target platform and injects the version through `ldflags`.
The [GitHub Actions distribution guide](../../build/go-cli-architecture/packaging/github-actions.md) has the config.

---

## Release Workflow

Trigger GoReleaser on tags. Update floating version tags.

A tag push runs `goreleaser/goreleaser-action@v6` with full history, then force-moves the major tag such as `v1` to the new release.
The [release automation guide](../../build/go-cli-architecture/packaging/release-automation.md) has the workflow, and the [distribution guide](../../build/go-cli-architecture/packaging/github-actions.md) the floating tag step.

!!! info "Floating Tags"
    `v1` points to the latest `v1.x.x`. Users pin to `@v1` for auto bug fix updates.

---

## Job Summaries

Write markdown summaries to `$GITHUB_STEP_SUMMARY`.

The Go code opens the file named in `GITHUB_STEP_SUMMARY` and appends a markdown table of results.
The [GitHub Actions distribution guide](../../build/go-cli-architecture/packaging/github-actions.md) has the function.

---

## Testing Your Action

### Local Testing

Build the binary and run it with `--check` against real files. Then run the action itself with `act`, the local GitHub Actions runner.

### CI Testing

A `test-action` job checks out the repo and runs the action with `uses: ./` against a known file.
The [GitHub Actions distribution guide](../../build/go-cli-architecture/packaging/github-actions.md) has both tests.

---

## Versioning Strategy

1. **Full versions**: `v1.0.0`, `v1.0.1`, `v1.1.0`
2. **Floating tags**: `v1` → latest `v1.x.x`

Users reference your action as:

```yaml
- uses: owner/my-action@v1  # Gets latest v1.x.x
```

---

## The Payoff

Go-based actions provide:

- **Fast execution**: No interpreter startup
- **Reliable distribution**: Binaries work everywhere
- **Simple updates**: Floating tags for easy upgrades
- **Professional polish**: Job summaries and exit codes

The setup effort pays off. You get better reliability and user experience.

---

## Related

- [Shipping a GitHub Action the Right Way](2025-12-06-shipping-a-github-action-the-right-way.md) - The motivation for this guide
- [Pre-commit Hooks with Binary Releases](2025-12-10-pre-commit-hooks-binary-releases.md) - Same patterns for pre-commit
- [Should Work ≠ Does Work](2025-12-08-always-works-qa-methodology.md) - Verify your action before release
- [Go CLI Architecture](../../build/go-cli-architecture/index.md) - Comprehensive CLI design patterns
