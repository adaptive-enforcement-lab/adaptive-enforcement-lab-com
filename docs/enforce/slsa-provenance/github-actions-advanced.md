---
title: Advanced GitHub Actions Patterns for SLSA
tags:
  - slsa
  - provenance
  - github-actions
  - supply-chain
  - security
  - attestation
  - workflows
  - developers
  - operators
description: >-
  Advanced GitHub Actions patterns for SLSA: multi-platform builds, monorepo patterns, organization-wide reusable workflows, and monitoring coverage.
---
# Advanced GitHub Actions Patterns for SLSA

Scale SLSA provenance from single repositories to organization-wide enforcement.

!!! info "Prerequisites"
    This guide assumes familiarity with [core GitHub Actions patterns](github-actions-patterns.md) for SLSA provenance. Start there if you're new to SLSA workflows.

---

## Overview

Advanced patterns covered:

1. **Multi-platform builds** - Provenance for matrix builds
2. **Monorepo patterns** - Multiple artifacts from single repository
3. **Organization-wide workflows** - Centralized SLSA infrastructure
4. **Monitoring and metrics** - Track adoption across repositories

---

## Pattern 1: Multi-Platform Build with Provenance

For Go, Rust, or other compiled languages with multi-platform builds:

```yaml
name: Multi-Platform Release

on:
  push:
    tags: ['v*']

permissions: {}

jobs:
  build:
    permissions:
      contents: read
    strategy:
      matrix:
        include:
          - os: ubuntu-latest
            goos: linux
            goarch: amd64
          - os: macos-latest
            goos: darwin
            goarch: arm64
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - name: Build binary
        run: |
          CGO_ENABLED=0 GOOS=${{ matrix.goos }} GOARCH=${{ matrix.goarch }} \
            go build -trimpath -ldflags="-s -w" \
            -o dist/myapp-${{ matrix.goos }}-${{ matrix.goarch }}
      - uses: actions/upload-artifact@v4
        with:
          name: binary-${{ matrix.goos }}-${{ matrix.goarch }}
          path: dist/

  combine-artifacts:
    needs: [build]
    permissions:
      contents: read
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    steps:
      - uses: actions/download-artifact@v4
        with:
          pattern: binary-*
          path: artifacts/
          merge-multiple: true
      - name: Generate combined hashes
        id: hash
        run: |
          cd artifacts
          sha256sum myapp-* | base64 -w0 > ../hashes.txt
          echo "hashes=$(cat ../hashes.txt)" >> "$GITHUB_OUTPUT"

  provenance:
    needs: [combine-artifacts]
    permissions:
      actions: read
      id-token: write
      contents: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
    with:
      base64-subjects: "${{ needs.combine-artifacts.outputs.hashes }}"
      upload-assets: true
```

**Key pattern**: Matrix builds upload separate artifacts, then `combine-artifacts` creates a single hash list for provenance generation.

---

## Pattern 2: Monorepo Multi-Artifact Provenance

For repositories with multiple independent artifacts:

```yaml
jobs:
  build-service-a:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make -C services/service-a build
      - uses: actions/upload-artifact@v4
        with:
          name: service-a
          path: services/service-a/dist/

  build-service-b:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make -C services/service-b build
      - uses: actions/upload-artifact@v4
        with:
          name: service-b
          path: services/service-b/dist/

  combine-hashes:
    needs: [build-service-a, build-service-b]
    permissions:
      contents: read
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: service-a
          path: artifacts/service-a/
      - uses: actions/download-artifact@v4
        with:
          name: service-b
          path: artifacts/service-b/
      - name: Generate combined hashes
        id: hash
        run: |
          find artifacts -type f -exec sha256sum {} \; | base64 -w0 > hashes.txt
          echo "hashes=$(cat hashes.txt)" >> "$GITHUB_OUTPUT"

  provenance:
    needs: [combine-hashes]
    permissions:
      actions: read
      id-token: write
      contents: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
    with:
      base64-subjects: "${{ needs.combine-hashes.outputs.hashes }}"
      upload-assets: true
```

**Result**: Single provenance file covers all artifacts from the monorepo release.

---

## Organization-Wide Adoption

### Centralized Reusable Workflows

Create a dedicated `.github` repository in your organization:

```text
adaptive-enforcement-lab/.github/
├── .github/
│   └── workflows/
│       ├── slsa-generic-provenance.yml
│       ├── slsa-container-provenance.yml
│       └── slsa-verification-gate.yml
└── README.md
```

Repositories in the organization can call these workflows:

```yaml
jobs:
  provenance:
    uses: adaptive-enforcement-lab/.github/.github/workflows/slsa-generic-provenance.yml@main
    permissions:
      actions: read
      id-token: write
      contents: write
    with:
      artifact-name: release-artifacts
      artifact-path: '*'
```

**Benefits**: Single source of truth, update once apply everywhere, enforce consistent implementation, audit all repositories from one location.

### Workflow Templates

Create starter workflows in `.github` repository:

```text
adaptive-enforcement-lab/.github/
└── workflow-templates/
    ├── slsa-release.yml
    └── slsa-release.properties.json
```

**File: `workflow-templates/slsa-release.yml`**

```yaml
name: SLSA Release

on:
  push:
    tags: ['v*']

permissions: {}

jobs:
  build:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make build
      - uses: actions/upload-artifact@v4
        with:
          name: release-artifacts
          path: dist/

  provenance:
    needs: [build]
    uses: adaptive-enforcement-lab/.github/.github/workflows/slsa-generic-provenance.yml@main
    permissions:
      actions: read
      id-token: write
      contents: write
    with:
      artifact-name: release-artifacts
      artifact-path: '*'
```

**File: `workflow-templates/slsa-release.properties.json`**

```json
{
  "name": "SLSA Release Workflow",
  "description": "Release workflow with SLSA Level 3 provenance",
  "iconName": "shield-check",
  "categories": ["Deployment"]
}
```

---

## Enforcement Patterns

### Organization-Wide Secrets

Store shared credentials in organization secrets:

- `SLSA_REGISTRY_USERNAME` - Container registry username
- `SLSA_REGISTRY_PASSWORD` - Container registry PAT

Reference in reusable workflows:

```yaml
secrets:
  registry-username:
    required: true
  registry-password:
    required: true
```

### Provenance Coverage Monitoring

Track SLSA adoption across the organization:

```yaml
name: SLSA Coverage Report

on:
  schedule:
    - cron: '0 0 * * 0'

permissions:
  contents: read

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - name: Check SLSA adoption
        run: |
          gh api orgs/${{ github.repository_owner }}/repos --paginate \
            --jq '.[] | select(.archived == false) | .name' > repos.txt

          while read repo; do
            WORKFLOW=$(gh api repos/${{ github.repository_owner }}/$repo/contents/.github/workflows \
              --jq '.[] | select(.name | contains("slsa")) | .name' || echo "")

            if [ -n "$WORKFLOW" ]; then
              echo "✓ $repo: SLSA workflow found"
            else
              echo "✗ $repo: No SLSA workflow"
            fi
          done < repos.txt
```

**Output**: Weekly report of SLSA adoption status.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Invalid hash format" | Hashes not base64-encoded | Use `sha256sum ... \| base64 -w0` |
| "Builder verification failed" | SHA pin instead of version tag | Use `@v2.1.0`, not `@abc123...` |
| "No provenance uploaded" | Missing `upload-assets: true` | Add to generator workflow call |
| "Workflow not reusable" | Missing `workflow_call` trigger | Add `on: workflow_call:` |
| "Permission denied" | Missing job permissions | Add explicit `permissions:` to job |

---

## Related Content

- **[GitHub Actions Patterns](github-actions-patterns.md)** - Core workflow patterns
- **[SLSA Implementation](slsa-provenance.md)** - Technical reference
- **[Adoption Roadmap](adoption-roadmap.md)** - Incremental rollout strategy
- **[Verification Workflows](verification-workflows.md)** - Verification enforcement

---

*Organization-wide SLSA adoption requires centralized infrastructure, consistent templates, and monitoring.*
