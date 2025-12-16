# Scorecard-Compliant Workflow Examples

Complete workflow patterns demonstrating job-level permissions, SLSA provenance, and source archive signing.

!!! example "Production Pattern"
    This workflow pattern is used in production for OpenSSF Scorecard 10/10 compliance. Adapt permissions and steps to your project's needs.

---

## Multi-Job Release Workflow

Complete pattern combining all Scorecard compliance practices:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions: {}  # Empty at workflow level - REQUIRED for Token-Permissions check

jobs:
  lint:
    permissions:
      contents: read  # Minimum needed for checkout
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
      - run: golangci-lint run

  test:
    permissions:
      contents: read  # Minimum needed for checkout
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
      - run: go test -race -coverprofile=coverage.out ./...

  build:
    needs: [lint, test]  # Fail fast on quality gates
    permissions:
      contents: read  # Minimum needed for checkout
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}  # Pass to provenance job
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - name: Build
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
      actions: read      # Read build artifacts
      id-token: write    # OIDC for provenance signing
      contents: write    # Upload provenance to release
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
    with:
      base64-subjects: "${{ needs.build.outputs.hashes }}"
      upload-assets: true  # Upload .intoto.jsonl to release

  sign-source-archives:
    needs: [provenance]
    permissions:
      contents: write   # Upload signatures to release
      id-token: write   # OIDC for Cosign keyless signing
    runs-on: ubuntu-latest
    steps:
      - name: Sign source archives
        run: |
          TAG="${{ github.ref_name }}"

          # Download GitHub's auto-generated archives
          curl -sL "https://github.com/${{ github.repository }}/archive/refs/tags/${TAG}.tar.gz" \
            -o "source_${TAG}.tar.gz"
          curl -sL "https://github.com/${{ github.repository }}/archive/refs/tags/${TAG}.zip" \
            -o "source_${TAG}.zip"

          # Sign with Cosign (keyless via OIDC)
          cosign sign-blob \
            --bundle "source_${TAG}.tar.gz.sig" \
            "source_${TAG}.tar.gz"
          cosign sign-blob \
            --bundle "source_${TAG}.zip.sig" \
            "source_${TAG}.zip"

          # Upload signatures to release
          gh release upload "$TAG" \
            "source_${TAG}.tar.gz.sig" \
            "source_${TAG}.zip.sig"
        env:
          GH_TOKEN: ${{ github.token }}
```

---

## Pattern Breakdown

### 1. Workflow-Level Permissions

```yaml
permissions: {}  # Empty at workflow level
```

**Why**: Forces explicit permission grants per job. Scorecard flags workflow-level permissions as over-privileged.

### 2. Job-Level Minimum Permissions

Each job declares only what it needs:

| Job | Permissions | Why |
| --- | ----------- | --- |
| lint | `contents: read` | Clone repo for linting |
| test | `contents: read` | Clone repo for testing |
| build | `contents: read` | Clone repo for building |
| provenance | `actions: read, id-token: write, contents: write` | Read artifacts, sign provenance, upload attestation |
| sign-source-archives | `contents: write, id-token: write` | Upload signatures, keyless signing |

### 3. Dependency Pinning

```yaml
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
```

**Pattern**: SHA digest with version comment for maintainability.

**Exception**: `slsa-framework/slsa-github-generator` uses version tags (documented in Renovate config).

### 4. SLSA Provenance Integration

```yaml
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
with:
  base64-subjects: "${{ needs.build.outputs.hashes }}"
  upload-assets: true
```

**Result**: `.intoto.jsonl` file uploaded to release, Signed-Releases score moves from 8 to 10.

### 5. Source Archive Signing

GitHub auto-generates source archives but doesn't sign them. Download, sign, re-upload:

```bash
curl -sL "https://github.com/${{ github.repository }}/archive/refs/tags/${TAG}.tar.gz" \
  -o "source_${TAG}.tar.gz"
cosign sign-blob --bundle "source_${TAG}.tar.gz.sig" "source_${TAG}.tar.gz"
gh release upload "$TAG" "source_${TAG}.tar.gz.sig"
```

---

## Scorecard Score Impact

| Check | Before | After | Fix |
| ----- | ------ | ----- | --- |
| Token-Permissions | 16 alerts | 0 alerts | Job-level permissions |
| Signed-Releases | 8/10 | 10/10 | SLSA provenance + source archive signing |
| Pinned-Dependencies | Warnings | Clean | SHA pins + documented exceptions |

---

## Variations

### Python Projects

```yaml
  build:
    permissions:
      contents: read
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - name: Build wheel
        run: |
          python -m build

      - name: Generate hashes
        id: hash
        run: |
          cd dist
          sha256sum *.whl *.tar.gz | base64 -w0 > ../hashes.txt
          echo "hashes=$(cat ../hashes.txt)" >> "$GITHUB_OUTPUT"
```

### Container Images

```yaml
  build:
    permissions:
      contents: read
      packages: write  # Push to GHCR
    runs-on: ubuntu-latest
    outputs:
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}

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

---

## Troubleshooting

### "Token-Permissions still showing alerts"

**Check**: Are permissions at workflow level non-empty?

**Fix**: Set `permissions: {}` at workflow level, move all grants to job level.

### "Provenance job fails with 'no artifacts found'"

**Check**: Is `hashes` output properly base64-encoded?

**Fix**: Use `base64 -w0` (no line wrapping) when generating hashes.

### "Source archive signatures not appearing in release"

**Check**: Does job have `contents: write` permission?

**Fix**: Grant `contents: write` to `sign-source-archives` job.

---

## Related Patterns

- [Scorecard Compliance](scorecard-compliance.md) - Principles behind these patterns
- [SLSA Provenance](../../enforce/slsa-provenance/slsa-provenance.md) - Deep dive on provenance generation
- [SBOM Generation](../sbom/sbom-generation.md) - Complete attestation stack

---

*This pattern achieves OpenSSF Scorecard 10/10 on Signed-Releases and 0 Token-Permissions alerts. Adapt permissions to your project's actual needs. These are examples, not requirements.*
