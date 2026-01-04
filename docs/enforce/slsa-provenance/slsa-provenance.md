---
title: SLSA Level 3 Provenance: Implementation Guide
tags:
  - slsa
  - provenance
  - supply-chain
  - security
  - attestation
  - developers
  - operators
description: >-
  Generate SLSA Level 3 provenance with slsa-github-generator. Cryptographically prove build integrity from source commit to artifact for OpenSSF Scorecard 10/10.
---
# SLSA Level 3 Provenance: Implementation Guide

Practical implementation patterns for `slsa-github-generator` in GitHub Actions workflows.

!!! info "Looking for Comprehensive Guidance?"
    This page is a focused implementation reference for `slsa-github-generator`. For complete SLSA guidance including level classification, verification workflows, and adoption roadmaps, see the **[SLSA Implementation Playbook](index.md)**.

!!! warning "Version Tag Requirement"
    `slsa-github-generator` **must** use version tags (`@v2.1.0`), not SHA pins. `slsa-verifier` validates against known version tags. SHA references fail verification. Document this exception in Renovate config.

---

## What This Guide Covers

**Implementation patterns for**:

- Workflow integration with `slsa-github-generator`
- Base64 hash generation for multiple artifacts
- Version tag pinning requirements
- Renovate configuration exceptions
- Source archive signing for GitHub releases
- Common troubleshooting scenarios

**Not covered here** (see playbook):

- SLSA vs SBOM comparison → [SLSA vs SBOM](slsa-vs-sbom.md)
- SLSA level classification → [SLSA Levels](slsa-levels.md)
- Verification workflows → [Verification Workflows](verification-workflows.md)
- GitHub Actions patterns → [GitHub Actions Patterns](github-actions-patterns.md)
- Toolchain integration → [Go](toolchains/go-integration.md), [Node.js](toolchains/node-integration.md), [Python](toolchains/python-integration.md)

---

## Quick Reference

**Outcome**: `.intoto.jsonl` attestation files that cryptographically prove build integrity

**OpenSSF Scorecard Impact**: Moves Signed-Releases check from 8/10 to 10/10

**Key Artifact**: Base64-encoded SHA256 hashes passed to `slsa-framework/slsa-github-generator`

---

## Implementation: slsa-github-generator

### Workflow Integration

```yaml
name: Release

permissions: {}  # Empty at workflow level

jobs:
  build:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - name: Build artifacts
        run: |
          go build -o dist/readability_linux_amd64
          go build -o dist/readability_darwin_amd64

      - name: Generate hashes
        id: hash
        run: |
          cd dist
          sha256sum readability_* | base64 -w0 > ../hashes.txt
          echo "hashes=$(cat ../hashes.txt)" >> "$GITHUB_OUTPUT"

      - uses: actions/upload-artifact@v4
        with:
          name: binaries
          path: dist/

  provenance:
    needs: [build]
    permissions:
      actions: read
      id-token: write
      contents: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
    with:
      base64-subjects: "${{ needs.build.outputs.hashes }}"
      upload-assets: true
```

### Critical Implementation Details

#### 1. Hash Format: Base64-Encoded

The generator requires base64-encoded SHA256 hashes, not hex or raw format:

```bash
# WRONG - hex format
sha256sum readability_* | xxd -p > hashes.txt

# CORRECT - base64 format
sha256sum readability_* | base64 -w0 > hashes.txt
```

#### 2. Version Tag Constraint

`slsa-github-generator` **must** use version tags, not SHA pins:

```yaml
# REQUIRED - version tag
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0

# WILL FAIL - SHA pin
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@abc123...
```

**Why**: `slsa-verifier` validates builder identity against known version tags. SHA references fail verification.

#### 3. Renovate Exception

Document this exception in `.github/renovate.json`:

```json
{
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "matchPackageNames": ["slsa-framework/slsa-github-generator"],
      "pinDigests": false,
      "extractVersion": "^(?<version>v\\d+\\.\\d+\\.\\d+)$"
    }
  ]
}
```

---

## Verification

### Command

```bash
slsa-verifier verify-artifact readability_linux_amd64 \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/adaptive-enforcement-lab/readability
```

### Expected Output

```text
Verified build using builder "https://github.com/slsa-framework/slsa-github-generator/..."
at commit 15dab4a45dd82c7c5eb28e2f89a83ac1794e97b9
PASSED: SLSA verification passed
```

---

## Source Archive Signing

GitHub auto-generates source archives for every release:

- `Source code (zip)`
- `Source code (tar.gz)`

These appear automatically but are **unsigned**. Scorecard flags unsigned assets.

### Solution: Download, Sign, Re-upload

```bash
TAG="v1.7.0"

# Download GitHub's generated archive
curl -sL "https://github.com/owner/repo/archive/refs/tags/${TAG}.tar.gz" \
  -o "source_${TAG}.tar.gz"

# Sign with Cosign
cosign sign-blob \
  --bundle "source_${TAG}.tar.gz.sig" \
  "source_${TAG}.tar.gz"

# Upload signature to release
gh release upload "$TAG" "source_${TAG}.tar.gz.sig"
```

---

## Troubleshooting

### Error: "Invalid hash format"

**Symptom**: Generator rejects hash input

**Cause**: Hashes not in base64 format

**Fix**: Use `sha256sum ... | base64 -w0`

### Error: "Builder verification failed"

**Symptom**: `slsa-verifier` fails validation

**Cause**: Using SHA pin instead of version tag

**Fix**: Use `@v2.1.0` format, not `@abc123...`

### Error: "No provenance found"

**Symptom**: Scorecard still shows 8/10

**Cause**: `.intoto.jsonl` file not uploaded to release

**Fix**: Ensure `upload-assets: true` in workflow

---

## Implementation Patterns

### Pattern 1: Single Binary Release

Use when building one artifact per platform:

```yaml
- name: Generate hashes
  id: hash
  run: |
    cd dist
    sha256sum myapp_linux_amd64 | base64 -w0 > ../hashes.txt
    echo "hashes=$(cat ../hashes.txt)" >> "$GITHUB_OUTPUT"
```

### Pattern 2: Multi-Binary Release

Use when building multiple artifacts (multi-platform, multi-architecture):

```yaml
- name: Generate hashes
  id: hash
  run: |
    cd dist
    sha256sum myapp_* | base64 -w0 > ../hashes.txt
    echo "hashes=$(cat ../hashes.txt)" >> "$GITHUB_OUTPUT"
```

### Pattern 3: Container Image Provenance

For container images, use `generator_container_slsa3.yml`:

```yaml
provenance:
  needs: [build]
  permissions:
    actions: read
    id-token: write
    packages: write
  uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.1.0
  with:
    image: ghcr.io/${{ github.repository }}
    digest: ${{ needs.build.outputs.digest }}
```

See [GitHub Actions Patterns](github-actions-patterns.md) for complete container workflows.

---

## Next Steps

**Expand your implementation**:

- **Verify provenance**: [Verification Workflows](verification-workflows.md) - Add verification gates to CI/CD
- **Enforce policies**: [Policy Templates](policy-templates.md) - Kyverno and OPA templates
- **Integrate toolchains**: [Go](toolchains/go-integration.md), [Node.js](toolchains/node-integration.md), [Python](toolchains/python-integration.md)
- **Plan adoption**: [Adoption Roadmap](adoption-roadmap.md) - Incremental SLSA 1→3 path

**Understand SLSA fundamentals**:

- **Level requirements**: [SLSA Levels](slsa-levels.md) - Detailed explanation of Levels 1-4
- **SLSA vs SBOM**: [Comparison Guide](slsa-vs-sbom.md) - When to use each
- **Runner classification**: [Runner Configuration](runner-configuration.md) - GitHub-hosted vs self-hosted

**Related patterns**:

- [OpenSSF Scorecard Compliance](../../secure/scorecard/scorecard-compliance.md) - Job-level permissions, dependency pinning
- [SBOM Generation](../../secure/sbom/sbom-generation.md) - Complete attestation stack

---

## Summary

**What you get**: `.intoto.jsonl` attestation files that cryptographically prove build integrity

**Critical requirement**: Use version tags (`@v2.1.0`), never SHA pins

**Common gotcha**: Hash format must be base64-encoded (`base64 -w0`), not hex

**Verification**: Use `slsa-verifier` to validate provenance before deployment

For comprehensive SLSA guidance, see the **[SLSA Implementation Playbook](index.md)**.
