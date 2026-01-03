---
tags:
  - slsa
  - provenance
  - supply-chain
  - security
  - attestation
  - adoption
  - slsa-level-3
  - developers
  - operators
  - security-teams
description: >-
  SLSA Level 3 implementation: isolated builds with slsa-github-generator, verification workflows, and OpenSSF Scorecard 10/10. Complete guide with validation checkpoints.
---

# Phase 3: SLSA Level 3 Implementation

Achieve build isolation with verification workflows and OpenSSF Scorecard 10/10.

!!! info "Phase 3 Overview"
    **Goal**: Build isolation with non-falsifiable provenance

    **Duration**: 2-4 weeks

    **Prerequisites**: Level 2 complete, GitHub-hosted or ephemeral runners

    **Outcome**: SLSA Level 3 provenance, OpenSSF 10/10, verification gates

---

## Overview

Phase 3 implements SLSA Level 3 using slsa-github-generator for isolated, non-falsifiable builds.

**Key difference from Level 2**: Build runs in isolated, ephemeral environment with provenance cryptographically proving isolation.

**Prerequisites**:

- Level 2 complete and validated
- GitHub-hosted runners or ephemeral self-hosted runners
- Team trained on verification procedures
- 2-4 weeks implementation timeline

**Also see**: [SLSA Adoption Roadmap](adoption-roadmap.md) for Phases 1 and 2.

---

## Implementation Steps

### Step 3.1: Migrate to slsa-github-generator

Replace your Level 2 workflow with the following configuration.

Create `.github/workflows/slsa-build.yml`:

```yaml
name: SLSA Level 3 Build

on:
  push:
    tags: ['v*']
  workflow_dispatch:

permissions: read-all

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      hashes: ${{ steps.hash.outputs.hashes }}
    steps:
      - uses: actions/checkout@v4

      - name: Build artifacts
        run: make build

      - name: Generate artifact hashes
        id: hash
        run: |
          cd dist
          sha256sum * | base64 -w0 > ../hashes.txt
          echo "hashes=$(cat ../hashes.txt)" >> "$GITHUB_OUTPUT"

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-artifacts
          path: dist/*
          if-no-files-found: error

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

**Key changes from Level 2**:

- Build job outputs artifact hashes
- Separate provenance job using slsa-github-generator reusable workflow
- Provenance job runs in isolated environment
- Permission model follows least-privilege principle

### Step 3.2: Add verification workflow

Create `.github/workflows/verify-slsa.yml` to verify provenance on release:

```yaml
name: Verify SLSA Provenance

on:
  release:
    types: [published]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - name: Download artifacts
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release download ${{ github.event.release.tag_name }} \
            --repo ${{ github.repository }}

      - name: Install slsa-verifier
        uses: slsa-framework/slsa-verifier/actions/installer@v2.6.0

      - name: Verify provenance
        run: |
          for artifact in dist/*; do
            echo "Verifying $artifact..."
            slsa-verifier verify-artifact "$artifact" \
              --provenance-path *.intoto.jsonl \
              --source-uri github.com/${{ github.repository }}
          done
```

**What this verifies**:

- Artifact hash matches provenance subject
- Provenance signature is valid
- Builder identity is slsa-github-generator
- Source repository matches expected value
- Build ran in isolated environment

### Step 3.3: Add PR verification gate

Create `.github/workflows/pr-slsa-check.yml` to enforce SLSA configuration in pull requests:

```yaml
name: PR SLSA Configuration Check

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  check-slsa-config:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Verify SLSA workflow exists
        run: |
          test -f .github/workflows/slsa-build.yml || \
            (echo "❌ Missing SLSA build workflow" && exit 1)
          echo "✓ SLSA workflow found"

      - name: Validate workflow permissions
        run: |
          grep -q "permissions: read-all" .github/workflows/slsa-build.yml || \
            (echo "❌ Incorrect permissions in SLSA workflow" && exit 1)
          echo "✓ Correct permissions configured"

      - name: Verify generator version
        run: |
          grep -q "slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2" \
            .github/workflows/slsa-build.yml || \
            (echo "❌ SLSA generator not found or wrong version" && exit 1)
          echo "✓ SLSA generator correctly configured"
```

### Step 3.4: Update release documentation

Create or update `docs/RELEASING.md` with Level 3 procedures:

```markdown
# Release Process

## SLSA Level 3 Provenance

All releases include SLSA Level 3 provenance attestation.

### Creating a Release

1. Create and push tag: `git tag v1.2.3 && git push origin v1.2.3`
2. GitHub Actions automatically builds artifacts and generates provenance
3. Verification workflow validates provenance
4. Release published with artifacts and provenance

### Verifying a Release

Download and verify any release:

```bash
# Download release assets
gh release download v1.2.3

# Verify with slsa-verifier
slsa-verifier verify-artifact <artifact> \
  --provenance-path *.intoto.jsonl \
  --source-uri github.com/org/repo
```

Expected output: `Verified signature against tlog entry...`

### Troubleshooting

**Verification fails**: Check builder identity matches slsa-github-generator

**Missing provenance**: Ensure upload-assets true in workflow

**Source mismatch**: Verify source-uri exactly matches repository

---

## Validation Checkpoint: Level 3

### Success Criteria

- [ ] All builds use slsa-github-generator
- [ ] Provenance files (.intoto.jsonl) attached to releases
- [ ] Verification workflow passes for all releases
- [ ] PR checks enforce SLSA workflow configuration
- [ ] OpenSSF Scorecard shows 10/10 for SLSA
- [ ] Team trained on verification procedures
- [ ] Release documentation updated
- [ ] Rollback procedure documented

### Comprehensive Validation

```bash
# Validate latest release
LATEST_TAG=$(gh release list --limit 1 --json tagName -q '.[0].tagName')
gh release download $LATEST_TAG

# Verify provenance exists
test -f *.intoto.jsonl || (echo "Missing provenance" && exit 1)

# Verify builder
jq -r '.predicate.buildType' *.intoto.jsonl | grep -q "slsa-github-generator" ||  (echo "Wrong builder" && exit 1)

# Verify with slsa-verifier
ARTIFACT=$(ls dist/* | head -1)
slsa-verifier verify-artifact "$ARTIFACT" \
  --provenance-path *.intoto.jsonl \
  --source-uri github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

### Common Issues and Solutions

**Issue**: Provenance not uploaded to release

- **Cause**: `upload-assets: true` not set in provenance job
- **Fix**: Add `upload-assets: true` in workflow with section
- **Validation**: Check release assets include `.intoto.jsonl` file

**Issue**: Verification fails with source mismatch

- **Cause**: `--source-uri` doesn't exactly match repository
- **Fix**: Use `github.com/${{ github.repository }}` or exact repo name
- **Validation**: Run `gh repo view --json nameWithOwner` to confirm

**Issue**: Builder identity unexpected

- **Cause**: Not using slsa-github-generator or wrong version
- **Fix**: Confirm using `generator_generic_slsa3.yml@v2.1.0`
- **Validation**: Check provenance buildType field

**Issue**: OpenSSF Scorecard still shows 8/10

- **Cause**: Scorecard updates run weekly, takes 24-48 hours
- **Fix**: Wait for next scorecard run
- **Validation**: Manually verify provenance exists, scorecard will update

**Issue**: Build hash mismatch

- **Cause**: Artifact modified between build and provenance jobs
- **Fix**: Ensure artifact uploaded and downloaded without modification
- **Validation**: Check artifact hash in provenance matches file

---

## Rollback Procedure

**When needed**: Verification failures, build blockers, critical release urgency

**Action**: Revert to Phase 2 workflow, validate Level 2 attestation works, communicate to team

**Impact**: Lose SLSA Level 3 but retain Level 2. No consumer breaking changes.

For detailed rollback steps, see [Adoption Management Guide](adoption-management.md).

---

## Success Metrics

Track these metrics to validate Phase 3 success:

### Coverage

- **Target**: 100% of releases have SLSA Level 3 provenance
- **Measurement**: Check `.intoto.jsonl` files in all releases
- **Frequency**: Per release

### Verification

- **Target**: 95% verification success rate
- **Measurement**: Verification workflow pass/fail ratio
- **Frequency**: Daily

### OpenSSF Scorecard

- **Target**: 10/10 score for SLSA
- **Measurement**: Check scorecard.dev
- **Frequency**: Weekly

### Team Confidence

- **Target**: 100% of release managers trained
- **Measurement**: Training completion and assessment
- **Frequency**: After each training session

---

## Next Steps

After successful Phase 3 implementation:

1. **Enforce verification**: Make verification workflow required status check
2. **Add policy enforcement**: Implement Kyverno/OPA policies (see [Policy Templates](policy-templates.md))
3. **Expand coverage**: Roll out to all repositories with external releases
4. **Automate compliance**: Integrate with compliance reporting tools
5. **Monitor continuously**: Set up alerts for verification failures

---

## Related Content

- **[SLSA Adoption Roadmap](adoption-roadmap.md)**: Overview and Phases 1-2
- **[Verification Workflows](verification-workflows.md)**: Advanced verification patterns
- **[Policy Templates](policy-templates.md)**: Enforce SLSA with Kyverno/OPA
- **[Adoption Management](adoption-management.md)**: Team coordination and risk management
- **[SLSA Levels](slsa-levels.md)**: Understand Level 3 requirements

---

*Level 3 is the industry standard. Isolated builds, non-falsifiable provenance, OpenSSF 10/10.*
