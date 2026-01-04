---
title: Tier 1: Score 7 to 8 (Good Hygiene → Strong Posture)
description: >-
  Quick wins for improving Scorecard scores from 7 to 8. Token permissions, security policy,
  dependency updates, and binary artifacts. 4 to 8 hours of focused work.
tags:
  - scorecard
  - compliance
  - quick-wins
  - supply-chain
---
# Tier 1: Score 7 to 8 (Good Hygiene → Strong Posture)

!!! tip "Key Insight"
    Token permissions and pinned dependencies are the highest ROI security improvements.

Quick wins with high security impact. These fixes clear visible gaps in your supply chain security.

**Estimated effort**: 4 to 8 hours of focused work

---

## What You Have at Score 7

- Automated testing in CI
- Basic dependency scanning
- Security policy documented
- Some branch protection enabled

**What's missing**: Job-level permissions, comprehensive protections, dependency automation

---

## Priority 1: Token-Permissions (0 to 2 hours)

**Target**: Clear all Token-Permissions alerts

**Problem**: Permissions scoped at workflow level grant maximum access to all jobs, including jobs that don't need it.

**Fix**: Move permissions from workflow level to job level.

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
```

**Result**: Every job flagged with Token-Permissions alert.

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

### Common Permission Patterns

**Read-Only Jobs** (Lint, Test, Build):

```yaml
permissions:
  contents: read  # Clone repository
```

**Release Jobs** (Upload Assets):

```yaml
permissions:
  contents: write  # Upload release assets
```

**Signing Jobs** (Cosign with OIDC):

```yaml
permissions:
  contents: write   # Upload signatures
  id-token: write   # OIDC token for keyless signing
```

**SLSA Provenance Jobs**:

```yaml
permissions:
  actions: read      # Read workflow artifacts
  id-token: write    # OIDC for provenance signing
  contents: write    # Upload provenance attestation
```

**Impact**: This single change can clear 16+ alerts overnight. Least privilege applied at narrowest scope.

**Details**: [Token-Permissions patterns](../../scorecard-compliance.md) | [16 Alerts Overnight blog](../../../../blog/posts/2025-12-20-sixteen-alerts-overnight.md)

---

## Priority 2: Security-Policy (0.5 hours)

**Target**: Security-Policy 10/10

**Fix**: Add `SECURITY.md` to repository root.

### Template

```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

Report security issues to security@example.com.

We'll respond within 48 hours with:
- Confirmation of receipt
- Initial assessment
- Expected timeline for fix

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

We'll coordinate disclosure timing with you.
```

**Impact**: Clear vulnerability reporting process for users and security researchers.

---

## Priority 3: Dependency-Update-Tool (1 hour)

**Target**: Dependency-Update-Tool 10/10

**Fix**: Enable Renovate or Dependabot.

### Renovate (Recommended)

Create `.github/renovate.json`:

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

**Why Renovate**:

- Automatic SHA pinning for GitHub Actions
- Configurable update schedules
- Grouping related updates
- Better PR descriptions

### Dependabot (Alternative)

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

**Note**: Dependabot doesn't auto-pin to SHA digests. Manual configuration needed.

**Impact**: Automated dependency updates with security patch tracking.

---

## Priority 4: Basic Branch Protection (1 to 2 hours)

**Target**: Branch-Protection 5/10 → 7/10

**Fix**: Enable basic protections in repository settings.

### Settings Path

Navigate to: Settings → Branches → Branch protection rules → main

### Required Settings

- ✅ **Require pull request before merging**
  - Prevents direct pushes to main
  - Forces all changes through PR review

- ✅ **Require approvals**: Set to **1**
  - At least one reviewer must approve
  - Can increase to 2 in Tier 2

- ✅ **Dismiss stale approvals when new commits are pushed**
  - Prevents sneaking in changes after approval
  - Forces re-review after updates

- ✅ **Require status checks to pass before merging**
  - CI must pass before merge
  - Add specific checks: tests, lint, security scans

- ✅ **Require branches to be up to date before merging**
  - Prevents merge conflicts
  - Ensures tests run against latest main

### Optional (Consider for Tier 1)

- ⚠️ **Require conversation resolution before merging**
  - All review comments must be resolved
  - Good practice but may slow small teams

- ⚠️ **Do not allow bypassing the above settings**
  - Applies to administrators too
  - Consider for larger teams

**Impact**: Prevents accidental force pushes and requires review before merge.

**Note**: These are repository settings, not workflow changes. Requires admin access.

---

## Priority 5: Binary-Artifacts (1 to 2 hours)

**Target**: Binary-Artifacts 10/10

**Fix**: Remove binaries from git. Use releases or package managers instead.

### Find Binaries in Git History

```bash
# Search for common binary extensions

git log --all --numstat --pretty="%H" --no-renames \
  -- "*.exe" "*.dll" "*.so" "*.dylib" "*.jar" "*.zip" "*.tar.gz" | \
  grep -v "^$" | head -20

# Find large files (likely binaries)

git rev-list --objects --all | \
  git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | \
  awk '/^blob/ {print substr($0,6)}' | \
  sort --numeric-sort --key=2 | \
  tail -20
```

### Removal Strategy

**For current binaries** (not in git history):

```bash
# Move to releases or external storage

gh release upload v1.0.0 binary_file

# Remove from git

git rm binary_file
git commit -m "Remove binary from git, use releases"
```

**For binaries in git history** (requires force push):

```bash
# Use BFG Repo-Cleaner or git-filter-repo

git filter-repo --path binary_file --invert-paths

# Force push (coordinate with team)

git push --force
```

**Alternative**: Accept the history. Focus on preventing new binaries.

### Prevent Future Binaries

Add to `.gitignore`:

```gitignore
# Binaries

*.exe
*.dll
*.so
*.dylib
*.jar

# Compressed archives (unless source releases)

*.zip
*.tar.gz
*.tgz

# OS-specific

*.DS_Store
Thumbs.db
```

**Impact**: Removes potential hiding places for malware in version control

---

## Checkpoint: Score 7 → 8

- ✅ Token-Permissions cleared (job-level scoping)
- ✅ Security-Policy documented (SECURITY.md added)
- ✅ Dependency updates automated (Renovate/Dependabot enabled)
- ✅ Basic branch protection enabled (PR required, 1 approval)
- ✅ Binaries removed from git (releases or package managers)

Expected Scorecard improvements:

| Check | Before | After |
| ----- | ------ | ----- |
| Token-Permissions | 0 to 3/10 | 10/10 |
| Security-Policy | 0/10 | 10/10 |
| Dependency-Update-Tool | 0/10 | 10/10 |
| Branch-Protection | 0 to 5/10 | 7/10 |
| Binary-Artifacts | 0 to 5/10 | 10/10 |

**Result**: Strong security hygiene. Ready for advanced supply chain protections in Tier 2

---
