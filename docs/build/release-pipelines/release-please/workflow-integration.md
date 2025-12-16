# Workflow Integration

GitHub Actions setup for release-please with proper token handling and output management.

---

## Recommended: GitHub App Token

Use a GitHub App token to ensure release-please PRs trigger build pipelines correctly. See [Workflow Triggers](../workflow-triggers.md) for why this matters.

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

For GitHub App setup, see [GitHub App Setup](../../../secure/github-apps/index.md).

!!! warning "Why Not GITHUB_TOKEN?"

    Using the default `GITHUB_TOKEN` prevents release-please PRs from
    triggering build pipelines. This is a [GitHub security measure](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#using-the-github_token-in-a-workflow)
    to prevent infinite loops. GitHub Apps are treated as separate actors
    and don't have this limitation.

---

## Output Reference

Release-please outputs follow the pattern `<path>--<output>`:

| Config Path | Output Variable |
| ------------- | ----------------- |
| `packages/backend` | `packages/backend--release_created` |
| `charts/my-chart` | `charts/my-chart--tag_name` |

Available outputs per package:

| Output | Description |
| -------- | ------------- |
| `release_created` | Boolean, true if release was created |
| `tag_name` | Git tag for the release |
| `version` | Semantic version (e.g., `1.2.3`) |
| `major`, `minor`, `patch` | Version components |

---

## Conditional Release Tagging

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

This naming is important for [workflow triggers](../workflow-triggers.md).

---

## Related

- [Release-Please Overview](index.md) - Configuration basics
- [Workflow Triggers](../workflow-triggers.md) - GITHUB_TOKEN compatibility
- [GitHub App Setup](../../../secure/github-apps/index.md) - Token generation
