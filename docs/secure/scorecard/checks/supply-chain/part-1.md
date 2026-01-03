---
description: >-
  Remediation playbooks for supply chain security checks including
  Pinned-Dependencies, Dangerous-Workflow, Binary-Artifacts, and SAST.
tags:
  - scorecard
  - supply-chain
  - security
---

# Supply Chain Security Checks

Critical checks that protect against supply chain attacks. These have the highest security impact and should be prioritized first.

**Covered checks:**

- **Pinned-Dependencies**: Pin dependencies to SHA digests
- **Dangerous-Workflow**: Prevent workflow-based attacks
- **Binary-Artifacts**: Remove binaries from source control
- **SAST**: Static application security testing

**Weight**: High. These checks prevent real supply chain attacks.

---

## Pinned-Dependencies

**Target**: 10/10 by pinning all GitHub Actions to SHA digests

**What it checks**: Whether dependencies (GitHub Actions, containers, third-party tools) are pinned to immutable references.

**Why it matters**: Version tags are mutable. `actions/checkout@v4` can change behavior overnight. SHA digests are immutable and prevent unexpected code execution.

### Understanding the Score

Scorecard analyzes:

- GitHub Actions references in `.github/workflows/*.yml`
- Container image references in Dockerfiles
- Installation scripts that download dependencies

**Scoring**:

- 10/10: All dependencies pinned to SHA digests
- 8/10: Most actions pinned, minor exceptions
- 5/10: Mix of version tags and SHA pins
- 0/10: No SHA pinning

### Before: Version Tags (Mutable)

```yaml
name: Release

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4  # Tag can be moved
      - uses: actions/setup-go@v5  # Tag can be moved
```

**Risk**: Action maintainer can update `v4` tag to point to malicious code. Your workflow automatically pulls the compromised version.

### After: SHA Pins (Immutable)

```yaml
name: Release

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - uses: actions/setup-go@0c52d547c9bc32b1aa3301fd7a9cb496313a4491  # v5.0.0
```

**Protection**: SHA digest is cryptographically immutable. Even if action is compromised, you run known-good code.

### Legitimate Exceptions

Some actions **require** version tags and will fail with SHA pins:

#### Exception 1: ossf/scorecard-action

```yaml
# MUST use version tag. Action verifies its own workflow identity
- uses: ossf/scorecard-action@v2.4.0
```

**Reason**: Internal workflow verification requires version tag for identity validation.

#### Exception 2: slsa-framework/slsa-github-generator

```yaml
# MUST use version tag. Verifier validates builder by tag
uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0
```

**Reason**: SLSA verifier checks builder identity against known version tags. SHA references fail cryptographic verification.

### Automated Pinning with Renovate

**Recommended**: Let Renovate handle pinning automatically.

Create `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "description": "Auto-pin GitHub Actions to SHA digests",
      "matchManagers": ["github-actions"],
      "pinDigests": true
    },
    {
      "description": "Exceptions that require version tags",
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

**Result**: Renovate automatically:

1. Pins all actions to SHA digests with version comment
2. Creates PRs when new versions are available
3. Preserves version tags for documented exceptions

### Manual Pinning

If you can't use Renovate:

```bash
# Find SHA for a specific version
gh api repos/actions/checkout/git/ref/tags/v4.1.1 --jq .object.sha

# Result: b4ffde65f46336ab88eb53be808477a3936bae11
```

**Format**:

```yaml
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

**Always include version comment**. Humans need to understand which version the SHA represents.

### Container Images

Pin container images to SHA digests too:

```dockerfile
# Before (mutable tag)
FROM golang:1.21

# After (immutable digest)
FROM golang:1.21@sha256:4746d26432a9117a5f58e95cb9f954ddf0de128e9d5816886514199316e4a2fb
```

### Third-Party Installation Scripts

Pin download URLs to specific versions:

```yaml
# Before (latest, mutable)
- run: curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh

# After (pinned version)
- run: |
    curl -sSfL https://github.com/golangci/golangci-lint/releases/download/v1.55.2/golangci-lint-1.55.2-linux-amd64.tar.gz \
      -o golangci-lint.tar.gz
    echo "ca21c961a33be3bc15e4292dc40c98c8dcc5463a7b6768a3afc123761630c09c  golangci-lint.tar.gz" | sha256sum -c -
    tar -xzf golangci-lint.tar.gz
```

**Add checksum verification** to prevent tampering during download.

### Troubleshooting

#### Pinned-Dependencies still flagging exceptions

**Expected**: Scorecard will flag `ossf/scorecard-action` and `slsa-framework/slsa-github-generator`.

**Action**: Document exceptions in repository README or PR descriptions. Scorecard score reflects reality. Some tools don't support SHA pinning.

#### Renovate not creating SHA pin PRs

**Check**: Is `pinDigests: true` in Renovate config?

**Check**: Does Renovate have write access to repository?

#### How do I find the SHA for a version tag?

```bash
# GitHub CLI
gh api repos/OWNER/REPO/git/ref/tags/VERSION --jq .object.sha

# Web UI
# Go to https://github.com/OWNER/REPO/releases
# Click on version tag → Commits → Copy SHA
```

---
