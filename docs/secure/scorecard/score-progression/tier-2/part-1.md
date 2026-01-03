---
description: >-
  Advanced security improvements for Scorecard scores 8 to 9. SLSA provenance, SHA pinning,
  SAST integration. Build integrity and comprehensive supply chain protections.
tags:

  - scorecard
  - compliance
  - slsa
  - supply-chain
  - provenance

---

# Tier 2: Score 8 to 9 (Strong Posture → Advanced Security)

Build provenance and comprehensive dependency pinning. These are the hardest but highest-impact improvements.

**Estimated effort**: 1 to 2 days

---

## What You Have at Score 8

- All quick wins from Tier 1 completed
- Job-level permissions scoped correctly
- Security policy documented
- Dependency updates automated
- Basic branch protection enabled
- Binaries removed from git

**What's missing**: Build provenance, comprehensive dependency pinning, static analysis

---

## Priority 1: Signed-Releases with SLSA Provenance (4 to 6 hours)

**Target**: Signed-Releases 8/10 → 10/10

**Problem**: Cosign signatures prove distribution integrity. They don't prove build integrity.

A signature says "this file is what I released." It doesn't say "this file came from a trusted build process."

### The Breakthrough: SLSA Level 3 Provenance

SLSA Level 3 provenance proves:

- **What source code** produced the artifact (exact commit SHA)
- **What build environment** was used (GitHub-hosted runner)
- **Who triggered** the build (workflow, not developer)
- **Build isolation** (no tampering during build)

The attestation is cryptographically bound to the artifacts. Change a byte, verification fails.

### Implementation

#### Step 1: Build job generates hashes

```yaml
jobs:
  build:
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    steps:

      - name: Build artifacts

        run: |
          go build -o readability_linux_amd64
          go build -o readability_darwin_amd64

      - name: Generate hashes

        id: hash
        run: |
          # IMPORTANT: Base64-encoded, not hex
          sha256sum readability_* | base64 -w0 > hashes.txt
          echo "hashes=$(cat hashes.txt)" >> "$GITHUB_OUTPUT"
```

#### Step 2: Provenance job consumes hashes

```yaml
  provenance:
    needs: [build]
    permissions:
      actions: read      # Read workflow artifacts
      id-token: write    # OIDC for provenance signing
      contents: write    # Upload provenance attestation
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
    with:
      base64-subjects: ${{ needs.build.outputs.hashes }}
      upload-assets: true

```

### Critical Details

#### 1. Must use version tag `@v2.1.0`, not SHA pin

```yaml
# REQUIRED - verifier validates against version tag
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0

# WRONG - verification will fail
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@abc123...

```

**Why**: `slsa-verifier` validates builder identity against known version tags. SHA references fail verification.

#### 2. Hashes must be base64-encoded

```bash
# CORRECT - base64 encoding
sha256sum readability_* | base64 -w0 > hashes.txt

# WRONG - hex encoding
sha256sum readability_* > hashes.txt

# WRONG - raw SHA256
sha256sum readability_* | xxd -p > hashes.txt
```

**3. Set `upload-assets: true`**

This uploads the `.intoto.jsonl` provenance file to the GitHub release. Without it, Scorecard can't find the provenance.

### Verification

After release, verify provenance:

```bash
slsa-verifier verify-artifact readability_linux_amd64 \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/owner/repo
```

**Expected output**:

```text
Verified build using builder "https://github.com/slsa-framework/slsa-github-generator/..."
at commit 15dab4a45dd82c7c5eb28e2f89a83ac1794e97b9
PASSED: SLSA verification passed
```

**Impact**: This single fix typically moves Signed-Releases from 8/10 to 10/10.

**Real-world example**: [Stuck at 8: The Journey to 10/10](../../../blog/posts/2025-12-18-scorecard-stuck-at-eight.md)

**Full implementation**: [SLSA Provenance Guide](../../../enforce/slsa-provenance/slsa-provenance.md)

---

## Priority 2: Source Archive Signing (1 hour)

**Target**: Close remaining Signed-Releases gaps

**Problem**: GitHub auto-generates source archives for every release:

```text
Release v1.7.0 Assets:
  readability_linux_amd64.tar.gz      ✅ Signed
  readability_linux_amd64.tar.gz.sig  ✅ Signature
  sbom.cdx.json                       ✅ Signed
  Source code (zip)                   ❌ UNSIGNED (auto-generated)
  Source code (tar.gz)                ❌ UNSIGNED (auto-generated)
```

Scorecard checks **every** asset. Unsigned auto-generated archives penalize the score.

### Solution: Download, Sign, Re-upload

```bash
TAG="v1.7.0"

# Download GitHub's auto-generated archives
curl -sL "https://github.com/owner/repo/archive/refs/tags/${TAG}.tar.gz" \
  -o "source_${TAG}.tar.gz"
curl -sL "https://github.com/owner/repo/archive/refs/tags/${TAG}.zip" \
  -o "source_${TAG}.zip"

# Sign with Cosign
cosign sign-blob --bundle "source_${TAG}.tar.gz.sig" "source_${TAG}.tar.gz"
cosign sign-blob --bundle "source_${TAG}.zip.sig" "source_${TAG}.zip"

# Upload signatures to release
gh release upload "$TAG" \
  "source_${TAG}.tar.gz.sig" \
  "source_${TAG}.zip.sig"
```

### Workflow Integration

```yaml

- name: Sign Source Archives

  run: |
    TAG="${{ github.ref_name }}"

    # Download auto-generated archives
    curl -sL "https://github.com/${{ github.repository }}/archive/refs/tags/${TAG}.tar.gz" \
      -o "source_${TAG}.tar.gz"
    curl -sL "https://github.com/${{ github.repository }}/archive/refs/tags/${TAG}.zip" \
      -o "source_${TAG}.zip"

    # Sign
    cosign sign-blob --bundle "source_${TAG}.tar.gz.sig" "source_${TAG}.tar.gz"
    cosign sign-blob --bundle "source_${TAG}.zip.sig" "source_${TAG}.zip"

    # Upload
    gh release upload "$TAG" \
      "source_${TAG}.tar.gz.sig" \
      "source_${TAG}.zip.sig"
  env:
    GH_TOKEN: ${{ github.token }}
```

**Impact**: Every asset in release is now signed. Scorecard checks pass.

**Details**: [Source Archive Signing](../scorecard-compliance.md#signed-releases-source-archive-gap)

---

## Priority 3: Pinned-Dependencies (2 to 4 hours)

**Target**: Pinned-Dependencies 10/10

**Fix**: Pin all GitHub Actions to SHA digests.

### Manual Pinning

```yaml
# Before - version tag only

- uses: actions/checkout@v4

# After - SHA pin with comment

- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
```

### Automated Pinning with Renovate

Update `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "pinDigests": true
    }
  ]
}
```

Renovate will:

- Automatically pin actions to SHA digests
- Add version tag as comment
- Update both SHA and tag when new versions release

### Valid Exceptions (Document These)

Some actions **require** version tags and fail with SHA pins:

#### 1. ossf/scorecard-action

```yaml
# MUST use version tag - internal verification fails with SHA

- uses: ossf/scorecard-action@v2.4.0
```

#### 2. slsa-framework/slsa-github-generator

```yaml
# MUST use version tag - verifier validates builder identity
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
```

### Document Exceptions in Renovate

```json
{
  "packageRules": [
    {
      "matchManagers": ["github-actions"],
      "pinDigests": true
    },
    {
      "matchManagers": ["github-actions"],
      "matchPackageNames": [
        "ossf/scorecard-action",
        "slsa-framework/slsa-github-generator"
      ],
      "pinDigests": false,
      "extractVersion": "^(?<version>v\\d+\\.\\d+\\.\\d+)$"
    }
  ]
}
```

**Impact**: Prevents unexpected behavior from dependency updates. Scorecard will still flag exceptions, but they're documented and justified.

**Details**: [Pinned-Dependencies patterns](../scorecard-compliance.md#pinned-dependencies-version-tag-exceptions)

---
