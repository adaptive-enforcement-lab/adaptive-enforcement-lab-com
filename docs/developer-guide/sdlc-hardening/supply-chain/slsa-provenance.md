# SLSA Level 3 Provenance Implementation

Build provenance that cryptographically proves what source code, build environment, and process produced an artifact.

!!! warning "Version Tag Requirement"
    `slsa-github-generator` **must** use version tags (`@v2.1.0`), not SHA pins. `slsa-verifier` validates against known version tags. SHA references fail verification. Document this exception in Renovate config.

---

## What SLSA Provenance Provides

SLSA Level 3 provenance generates `.intoto.jsonl` attestation files signed by GitHub's OIDC provider that prove:

- **Exact source commit** that produced the artifact
- **Isolated build environment** (GitHub-hosted runner)
- **Workflow identity** that triggered the build
- **Tamper-evident artifact linkage** via cryptographic hashing

This moves beyond signatures (which only prove distribution integrity) to prove **build integrity**.

---

## OpenSSF Scorecard Impact

- **Score 8**: Cryptographic signatures present (Cosign, GPG)
- **Score 10**: SLSA provenance present (`.intoto.jsonl` files)

Provenance is what moves Signed-Releases from 8 to 10.

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

## Security Properties

SLSA Level 3 provenance provides:

- **Non-falsifiable**: Signed by GitHub's OIDC, not developer credentials
- **Tamper-evident**: Cryptographic binding to artifacts
- **Auditable**: Build parameters recorded in attestation
- **Isolated**: GitHub-hosted runners prevent local tampering

This is the gap between "I signed this" and "GitHub's infrastructure built this from this commit."

---

## Related Patterns

- [OpenSSF Scorecard Compliance](scorecard-compliance.md) - Job-level permissions, dependency pinning
- [SBOM Generation](../sbom-generation.md) - Complete attestation stack
- [Zero-Vulnerability Pipelines](../../../blog/posts/2025-12-15-zero-vulnerability-pipelines.md) - Trivy + SBOM + SLSA

---

*SLSA provenance moves from signatures (8/10) to cryptographically proven builds (10/10). The gap is build integrity, not distribution integrity.*
