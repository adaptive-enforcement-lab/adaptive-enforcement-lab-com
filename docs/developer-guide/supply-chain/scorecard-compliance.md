# OpenSSF Scorecard Compliance

Practical patterns for clearing Scorecard findings: job-level permissions, dependency pinning, and source archive signing.

!!! tip "Complete Workflow Examples"
    For full working examples combining these patterns, see [Scorecard Workflow Examples](scorecard-workflow-examples.md). This guide explains the principles; that guide shows production code.

---

## Token-Permissions: Job-Level Scoping

**Problem**: Permissions defined at workflow level grant maximum access to all jobs, including jobs that don't need it.

**Scorecard Principle**: Grant minimum permissions per job, not maximum permissions per workflow.

### Before: Workflow-Level Permissions (16 Alerts)

```yaml
name: Release

permissions:
  contents: write   # ALL jobs get this
  id-token: write   # ALL jobs get this

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: golangci-lint run  # Doesn't need write or OIDC!

  test:
    runs-on: ubuntu-latest
    steps:
      - run: go test ./...  # Doesn't need write or OIDC!

  sign-releases:
    runs-on: ubuntu-latest
    steps:
      - run: cosign sign-blob ...  # DOES need write and OIDC
```

**Result**: 16 Token-Permissions alerts (every job flagged).

### After: Job-Level Permissions (0 Alerts)

```yaml
name: Release

permissions: {}  # Empty at workflow level

jobs:
  lint:
    permissions:
      contents: read  # Only what's needed
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
      - run: golangci-lint run

  test:
    permissions:
      contents: read  # Only what's needed
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
      - run: go test ./...

  sign-releases:
    permissions:
      contents: write   # Upload signatures
      id-token: write   # OIDC for Cosign
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
      - run: cosign sign-blob ...
```

**Result**: 0 alerts. Least privilege applied at narrowest scope.

---

## Common Permission Patterns

### Read-Only Jobs (Lint, Test, Build)

```yaml
permissions:
  contents: read  # Clone repository
```

### Release Jobs (Upload Assets)

```yaml
permissions:
  contents: write  # Upload release assets
```

### Signing Jobs (Cosign with OIDC)

```yaml
permissions:
  contents: write   # Upload signatures
  id-token: write   # OIDC token for keyless signing
```

### SLSA Provenance Jobs

```yaml
permissions:
  actions: read      # Read workflow artifacts
  id-token: write    # OIDC for provenance signing
  contents: write    # Upload provenance attestation
```

### PR Comment Jobs

```yaml
permissions:
  contents: read        # Clone repository
  pull-requests: write  # Comment on PRs
```

---

## Signed-Releases: Source Archive Gap

**Problem**: GitHub auto-generates source archives for every release, but they're unsigned.

Scorecard checks **every** asset in a release:

```text
Release v1.7.0 Assets:
  readability_linux_amd64.tar.gz      ✅ Signed
  readability_linux_amd64.tar.gz.sig  ✅ Signature
  sbom.cdx.json                       ✅ Signed
  Source code (zip)                   ❌ UNSIGNED (auto-generated)
  Source code (tar.gz)                ❌ UNSIGNED (auto-generated)
```

**Result**: Signed-Releases score penalized for unsigned auto-generated archives.

### Solution: Download, Sign, Re-upload

```bash
TAG="v1.7.0"

# Download GitHub's auto-generated archive
curl -sL "https://github.com/owner/repo/archive/refs/tags/${TAG}.tar.gz" \
  -o "source_${TAG}.tar.gz"

# Sign with Cosign
cosign sign-blob \
  --bundle "source_${TAG}.tar.gz.sig" \
  "source_${TAG}.tar.gz"

# Upload signature to release
gh release upload "$TAG" "source_${TAG}.tar.gz.sig"
```

**Workflow Integration**:

```yaml
- name: Sign Source Archives
  run: |
    TAG="${{ github.ref_name }}"
    curl -sL "https://github.com/${{ github.repository }}/archive/refs/tags/${TAG}.tar.gz" \
      -o "source_${TAG}.tar.gz"
    curl -sL "https://github.com/${{ github.repository }}/archive/refs/tags/${TAG}.zip" \
      -o "source_${TAG}.zip"

    cosign sign-blob --bundle "source_${TAG}.tar.gz.sig" "source_${TAG}.tar.gz"
    cosign sign-blob --bundle "source_${TAG}.zip.sig" "source_${TAG}.zip"

    gh release upload "$TAG" \
      "source_${TAG}.tar.gz.sig" \
      "source_${TAG}.zip.sig"
  env:
    GH_TOKEN: ${{ github.token }}
```

---

## Pinned-Dependencies: Version Tag Exceptions

**Scorecard Rule**: Pin actions to SHA digests, not version tags.

```yaml
# Scorecard wants this
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
```

**Exception**: Some actions **require** version tags and fail with SHA pins.

### Valid Exceptions

#### 1. ossf/scorecard-action

```yaml
# MUST use version tag - internal workflow verification fails with SHA
- uses: ossf/scorecard-action@v2.4.0
```

**Reason**: Action verifies its own workflow identity using version tags.

#### 2. slsa-framework/slsa-github-generator

```yaml
# MUST use version tag - verifier validates builder identity
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
```

**Reason**: `slsa-verifier` validates against known version tags. SHA references fail verification.

### Documenting Exceptions in Renovate

```json
{
  "packageRules": [
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

**Why Document**: Scorecard will still flag these, but Renovate won't auto-convert them to SHA pins. Document the exception in PR descriptions or repository docs.

---

## Branch-Protection: Settings vs Code

**Problem**: Some Scorecard findings require repository settings, not workflow changes.

### Example Findings

```text
- Warn: required approving review count is 1 on branch 'main'
- Warn: 'last push approval' is disabled on branch 'main'
```

### Solution: Repository Settings

These need GitHub admin access:

1. **Settings → Branches → Branch protection rules → main**
2. **Require approvals**: Increase from 1 to 2+
3. **Require approval of the most recent reviewable push**: Enable

**Why This Matters**: Prevents PR author from bypassing reviews by pushing new commits after approval.

**For complete workflow examples** combining all these patterns, see [Scorecard Workflow Examples](scorecard-workflow-examples.md).

---

## Scorecard Score Progression

| Check | Before | After |
| ----- | ------ | ----- |
| Token-Permissions | 16 alerts | 0 alerts |
| Signed-Releases | 8/10 | 10/10 |
| Pinned-Dependencies | Warnings | Clean (with documented exceptions) |
| Branch-Protection | 5/10 | 8/10 |

**Different problems, different solutions:**

- Token-Permissions → Code (job-level scoping)
- Signed-Releases → SLSA provenance + source archive signing
- Pinned-Dependencies → SHA pins + documented exceptions
- Branch-Protection → Repository settings

---

## Troubleshooting

### "Token-Permissions alerts still appearing"

**Check**: Are permissions defined at workflow level?

**Fix**: Move to job level, set workflow level to `permissions: {}`

### "Signed-Releases still at 8/10"

**Check**: Is `.intoto.jsonl` file uploaded to release?

**Fix**: Ensure `upload-assets: true` in SLSA workflow

### "Pinned-Dependencies flagging required version tags"

**Expected**: Some tools require version tags (documented exceptions)

**Action**: Document in Renovate config, explain in PR descriptions

---

## Related Patterns

- [Scorecard Workflow Examples](scorecard-workflow-examples.md) - Complete working workflows
- [SLSA Level 3 Provenance](slsa-provenance.md) - Build attestations for 10/10
- [SBOM Generation](../sdlc-hardening/sbom-generation.md) - Complete attestation stack
- [OpenSSF Best Practices Badge](../../blog/posts/2025-12-17-openssf-badge-two-hours.md) - Scorecard validates what badge certifies

---

*Scorecard compliance is about applying security principles at the right scope: permissions per job, signatures per asset, pins per action. One commit cleared 16 alerts. Principle: least privilege at narrowest scope.*
