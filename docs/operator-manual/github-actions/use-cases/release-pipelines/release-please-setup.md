# Release-Please Configuration

[Release-please](https://github.com/marketplace/actions/release-please-action) automates version management based on conventional commits. It creates release PRs with updated changelogs, version bumps, and Git tags.

---

## Overview

Release-please reads your commit history and:

1. Groups changes by type (feat, fix, chore, etc.)
2. Generates changelogs
3. Bumps versions according to semantic versioning
4. Creates pull requests for releases
5. Tags releases when PRs merge

---

## Configuration Files

### release-please-config.json

The main configuration file defines packages and their versioning behavior:

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "include-v-in-tag": false,
  "tag-separator": "-",
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance" },
    { "type": "refactor", "section": "Code Refactoring" },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "chore", "section": "Maintenance" },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "ci", "section": "CI/CD", "hidden": true }
  ],
  "packages": {
    "charts/my-app": {
      "release-type": "helm",
      "component": "my-app",
      "include-component-in-tag": false
    },
    "packages/backend": {
      "release-type": "node",
      "component": "backend",
      "package-name": "my-backend",
      "include-component-in-tag": true
    },
    "packages/frontend": {
      "release-type": "node",
      "component": "frontend",
      "package-name": "my-frontend",
      "include-component-in-tag": true
    }
  },
  "separate-pull-requests": true
}
```

### .release-please-manifest.json

Tracks current versions for each package:

```json
{
  "charts/my-app": "1.0.0",
  "packages/backend": "1.0.0",
  "packages/frontend": "1.0.0"
}
```

---

## Configuration Options

### Global Options

| Option | Description | Example |
|--------|-------------|---------|
| `include-v-in-tag` | Prefix tags with `v` | `true` = `v1.0.0`, `false` = `1.0.0` |
| `tag-separator` | Separator between component and version | `-` = `backend-1.0.0` |
| `separate-pull-requests` | Create one PR per component | Recommended for monorepos |
| `changelog-sections` | How to group commits in changelogs | See example above |

### Package Options

| Option | Description | Values |
|--------|-------------|--------|
| `release-type` | Package ecosystem | `node`, `helm`, `simple`, `python`, `go`, etc. |
| `component` | Component name for tagging | Any string |
| `include-component-in-tag` | Include component in tag | `true` = `backend-1.0.0` |
| `package-name` | Package name (for node, etc.) | Matches package.json name |

---

## Release Types

### Node

For npm packages. Updates `package.json` and `package-lock.json`:

```json
{
  "packages/my-package": {
    "release-type": "node",
    "component": "my-package",
    "package-name": "@org/my-package"
  }
}
```

### Helm

For Helm charts. Updates `Chart.yaml`:

```json
{
  "charts/my-chart": {
    "release-type": "helm",
    "component": "my-chart",
    "include-component-in-tag": false
  }
}
```

!!! tip "Helm Versioning"

    Set `include-component-in-tag: false` for Helm charts so tags match
    `Chart.yaml` version (e.g., `1.0.0` not `my-chart-1.0.0`).

### Simple

For generic versioning. Updates a `version.txt` or similar:

```json
{
  ".": {
    "release-type": "simple",
    "component": "root"
  }
}
```

---

## Changelog Sections

Control how commits appear in changelogs:

```json
{
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance" },
    { "type": "refactor", "section": "Code Refactoring", "hidden": true },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "chore", "section": "Maintenance" },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "ci", "section": "CI/CD", "hidden": true }
  ]
}
```

| Property | Description |
|----------|-------------|
| `type` | Conventional commit type to match |
| `section` | Heading in changelog |
| `hidden` | Exclude from changelog (still affects versioning) |

---

## Workflow Integration

### Recommended: GitHub App Token

Use a GitHub App token to ensure release-please PRs trigger build pipelines correctly. See [Workflow Triggers](workflow-triggers.md) for why this matters.

```yaml
name: Release Please
on:
  push:
    branches:
      - main

jobs:
  release-please:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    outputs:
      releases_created: ${{ steps.release.outputs.releases_created }}
      backend_release: ${{ steps.release.outputs['packages/backend--release_created'] }}
      frontend_release: ${{ steps.release.outputs['packages/frontend--release_created'] }}
    steps:
      - name: Generate App Token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - uses: googleapis/release-please-action@v4
        id: release
        with:
          token: ${{ steps.app-token.outputs.token }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
```

For GitHub App setup, see [GitHub App Setup](../../github-app-setup/index.md).

!!! warning "Why Not GITHUB_TOKEN?"

    Using the default `GITHUB_TOKEN` prevents release-please PRs from
    triggering build pipelines. This is a [GitHub security measure](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#using-the-github_token-in-a-workflow)
    to prevent infinite loops. GitHub Apps are treated as separate actors
    and don't have this limitation.

### Output Reference

Release-please outputs follow the pattern `<path>--<output>`:

| Config Path | Output Variable |
|-------------|-----------------|
| `packages/backend` | `packages/backend--release_created` |
| `charts/my-chart` | `charts/my-chart--tag_name` |

Available outputs per package:

| Output | Description |
|--------|-------------|
| `release_created` | Boolean, true if release was created |
| `tag_name` | Git tag for the release |
| `version` | Semantic version (e.g., `1.2.3`) |
| `major`, `minor`, `patch` | Version components |

### Conditional Release Tagging

Pass release status to downstream jobs:

```yaml
build-container:
  needs: release-please
  uses: ./.github/workflows/container-build.yaml
  with:
    is-release: ${{ needs.release-please.outputs.backend_release == 'true' }}
```

When `is-release` is true, tag containers with:

- Semantic version (e.g., `1.2.3`)
- `latest` tag

When false, use only build-specific tags (e.g., `build-abc123`).

---

## Monorepo Strategy

For monorepos with multiple components:

```json
{
  "separate-pull-requests": true,
  "packages": {
    "packages/shared": {
      "release-type": "node",
      "component": "shared"
    },
    "packages/backend": {
      "release-type": "node",
      "component": "backend"
    },
    "packages/frontend": {
      "release-type": "node",
      "component": "frontend"
    }
  }
}
```

!!! info "Separate PRs"

    With `separate-pull-requests: true`, each component gets its own
    release PR. This allows independent versioning and releases.

---

## Branch Naming

Release-please creates branches with a specific pattern:

- Simple repos: `release-please--branches--main`
- Monorepos: `release-please--branches--main--component-name`

This naming is important for [workflow triggers](workflow-triggers.md).

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| No PR created | No conventional commits | Use `feat:`, `fix:`, etc. prefixes |
| Wrong version bump | Commit type mismatch | Check commit types match changelog-sections |
| Changelog empty | Hidden sections | Remove `hidden: true` from desired sections |
| Duplicate tags | Inconsistent component settings | Verify `include-component-in-tag` consistency |

---

## Next Steps

- [Change Detection](change-detection.md) - Skip unnecessary builds
- [Workflow Triggers](workflow-triggers.md) - GITHUB_TOKEN compatibility

---

## References

- [Release-please Action](https://github.com/marketplace/actions/release-please-action) - GitHub Marketplace
- [Release-please repository](https://github.com/googleapis/release-please) - googleapis
- [Conventional Commits](https://www.conventionalcommits.org/) - Specification
