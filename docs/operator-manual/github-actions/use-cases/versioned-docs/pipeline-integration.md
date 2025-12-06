# Pipeline Integration

Unified release pipeline that handles versioning, builds, and documentation deployment.

---

## Complete Workflow

This workflow integrates release-please, artifact builds, and versioned documentation:

```yaml
name: Release Pipeline

on:
  push:
    branches:
      - main
  workflow_dispatch:
    inputs:
      skip_release_please:
        description: "Skip release-please (use for manual rebuilds)"
        type: boolean
        default: false
      force_docs:
        description: "Force docs rebuild"
        type: boolean
        default: false

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: write
  pull-requests: write
  pages: write
  id-token: write

jobs:
  release-please:
    name: Release Please
    runs-on: ubuntu-latest
    if: ${{ !inputs.skip_release_please }}
    outputs:
      release_created: ${{ steps.release.outputs.release_created }}
      tag_name: ${{ steps.release.outputs.tag_name }}
      version: ${{ steps.release.outputs.version }}
      major: ${{ steps.release.outputs.major }}
    steps:
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

  detect-changes:
    name: Detect Changes
    runs-on: ubuntu-latest
    needs: release-please
    if: always() && !cancelled()
    outputs:
      docs_changed: ${{ steps.changes.outputs.docs_any_changed }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changed paths
        id: changes
        uses: tj-actions/changed-files@v45
        with:
          files_yaml: |
            docs:
              - docs/**
              - mkdocs.yml

  build-docs:
    name: Build Documentation
    needs: [release-please, detect-changes]
    if: |
      always() && !cancelled() &&
      (needs.detect-changes.outputs.docs_changed == 'true' ||
       inputs.force_docs == true ||
       needs.release-please.outputs.release_created == 'true')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Configure Git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Determine version alias
        id: version
        run: |
          if [ "${{ needs.release-please.outputs.release_created }}" == "true" ]; then
            VERSION="${{ needs.release-please.outputs.version }}"
            MAJOR="${{ needs.release-please.outputs.major }}"
            echo "version=${VERSION}" >> "$GITHUB_OUTPUT"
            echo "alias=v${MAJOR}" >> "$GITHUB_OUTPUT"
          else
            echo "version=dev" >> "$GITHUB_OUTPUT"
            echo "alias=" >> "$GITHUB_OUTPUT"
          fi

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

---

## Key Design Decisions

### Conditional Job Execution

```yaml
if: |
  always() && !cancelled() &&
  (needs.detect-changes.outputs.docs_changed == 'true' ||
   inputs.force_docs == true ||
   needs.release-please.outputs.release_created == 'true')
```

The build-docs job runs when:

1. **Docs changed** - Files in `docs/` or `mkdocs.yml` modified
2. **Force flag** - Manual rebuild requested
3. **Release created** - Always update docs on release

This implements [work avoidance](../work-avoidance/index.md) - no wasted builds when only code changes.

### always() and !cancelled()

```yaml
if: always() && !cancelled()
```

The `detect-changes` job must run even if `release-please` is skipped (via `skip_release_please` input). Using `always()` ensures downstream jobs evaluate their conditions properly.

### Concurrency Control

```yaml
concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false
```

Never cancel release pipelines mid-flight. Partial releases cause inconsistent states.

---

## Mike Commands

### Release Deployment

```bash
mike deploy --push --update-aliases 1.2.3 v1 latest
```

This:

1. Deploys version `1.2.3`
2. Creates alias `v1` pointing to `1.2.3`
3. Creates alias `latest` pointing to `1.2.3`
4. Pushes to gh-pages branch

### Development Deployment

```bash
mike deploy --push dev
```

Updates only the `dev` version without touching aliases.

---

## GitHub Pages Setup

### Enable Pages

```bash
gh api repos/{owner}/{repo}/pages -X POST \
  --input - <<< '{"source":{"branch":"gh-pages","path":"/"}}'
```

### Custom Domain

```bash
gh api repos/{owner}/{repo}/pages -X PUT \
  --input - <<< '{"cname":"docs.example.com"}'
```

---

## Related

- [Mike Configuration](mike-configuration.md) - Local setup
- [Version Strategies](version-strategies.md) - Aliasing patterns
- [Release-Please Workflow Integration](../release-pipelines/release-please/workflow-integration.md) - Token handling
