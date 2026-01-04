---
title: Signed-Releases Advanced Guide
description: >-
  Advanced troubleshooting and remediation for OpenSSF Scorecard Signed-Releases.
  Fix common provenance issues and optimize SLSA implementation.
tags:

  - scorecard
  - slsa
  - troubleshooting

---
# Signed-Releases Advanced Guide

!!! tip "Key Insight"
    SLSA provenance provides cryptographic proof of build integrity.

This guide covers troubleshooting and advanced patterns for Signed-Releases.

**Prerequisites**: Read [Signed-Releases check](./signed-releases.md) first for basics.

## Troubleshooting

### Issue: Provenance generation fails with "invalid base64 input"

**Cause**: Hash format not base64-encoded.

**Fix**:

```bash
# Ensure base64 encoding in hash generation step

sha256sum readability_* | base64 -w0 > hashes.txt

```bash
### Issue: Verifier fails with "builder identity not trusted"

**Cause**: Using SHA pin instead of version tag for `slsa-github-generator`.

**Fix**:

```yaml
# Change from SHA pin

uses: slsa-framework/slsa-github-generator/...@abc123...

# To version tag

uses: slsa-framework/slsa-github-generator/...@v2.1.0

```bash
### Issue: Score stuck at 8/10 despite provenance

**Cause**: GitHub auto-generated source archives are unsigned.

**Fix**: Add source archive signing job (see "Source Archive Signing" section above).

### Issue: Provenance job can't find artifacts

**Cause**: Build job didn't upload artifacts or `needs:` dependency missing.

**Fix**:

```yaml
build:
  steps:
    # Upload artifacts

    - uses: actions/upload-artifact@v4

      with:
        name: binaries
        path: dist/

provenance:
  needs: [build]  # Ensure dependency
  uses: slsa-framework/slsa-github-generator/...

```bash
### Remediation Steps

**Time estimate**: 3 to 4 hours (initial setup), 15 minutes per release (ongoing)

**Prerequisites**:

- GitHub Releases workflow configured
- Artifacts built in isolated job
- OIDC token permissions available

**Step 1: Generate artifact hashes** (30 minutes)

Modify build job to output base64-encoded hashes:

```yaml

- name: Generate hashes

  id: hash
  run: |
    cd dist
    sha256sum * | base64 -w0 > ../hashes.txt
    echo "hashes=$(cat ../hashes.txt)" >> "$GITHUB_OUTPUT"

```bash
**Step 2: Add provenance job** (1 hour)

Add reusable workflow call:

```yaml
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

```bash
**Step 3: Configure Renovate exception** (15 minutes)

Add to `.github/renovate.json`:

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

```bash
**Step 4: Add source archive signing** (1 hour)

Create job to sign GitHub auto-generated source archives:

```yaml
sign-source-archives:
  needs: [provenance]
  permissions:
    contents: write
    id-token: write
  runs-on: ubuntu-latest
  steps:

    - name: Sign source archives

      run: |
        gh release download ${{ github.ref_name }} \
          --pattern "*.zip" --pattern "*.tar.gz" --dir source/
        for file in source/*; do
          cosign sign-blob "$file" --output-signature="${file}.sig" --yes
        done
        gh release upload ${{ github.ref_name }} source/*.sig
      env:
        GH_TOKEN: ${{ github.token }}

```bash
**Step 5: Test with release** (30 minutes)

Create test release and verify:

```bash
# Check release assets include provenance

gh release view v0.0.1-test

# Verify provenance

slsa-verifier verify-artifact artifact \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/your-org/your-repo

# Verify source archive signatures

cosign verify-blob Source_code.zip \
  --signature Source_code.zip.sig \
  --certificate-identity-regexp "https://github.com/your-org" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com"

```bash
**Step 6: Validate Scorecard** (15 minutes)

Run Scorecard and confirm 10/10:

```bash
docker run -e GITHUB_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
  --repo=github.com/your-org/your-repo --show-details | grep Signed-Releases

```bash
---

---

## Related Content

**Back to basics**:

- [Signed-Releases Check](./signed-releases.md) - Core implementation guide

**Other Release Security checks**:

- [Packaging](./packaging.md) - Package registry publishing
- [License](./license.md) - OSI-approved license detection

---

*Advanced Signed-Releases guide covers troubleshooting provenance failures and score optimization.*
