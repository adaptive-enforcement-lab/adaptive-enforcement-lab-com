---
description: >-
  Advanced vulnerability management for OpenSSF Scorecard. Handle unfixable 
  vulnerabilities, false positives, and disclosure processes.
tags:
  - scorecard
  - vulnerabilities
  - cve
  - security-advisories
---

# Advanced Vulnerability Management

This guide covers complex vulnerability scenarios for the Scorecard Vulnerabilities check.

**Prerequisites**: Read [Vulnerabilities check](./vulnerabilities.md) first for basics.

### Handling Unfixable Vulnerabilities

**Scenario**: Vulnerability exists but no patch available yet.

**Options**:

#### Option 1: Wait for Patch

If vulnerability is low severity and doesn't affect your use case:

```markdown
# Known Vulnerabilities

## CVE-2024-1234 in dependency-name

- **Severity**: Low
- **Status**: Awaiting upstream patch
- **Mitigation**: Vulnerability requires physical access to server,
  not exploitable in our deployment model
- **Tracking**: https://github.com/upstream/repo/issues/1234
```

**Document** in repository README or security advisory.

#### Option 2: Pin to Last Good Version

```json
{
  "dependencies": {
    "vulnerable-package": "1.2.3"
  },
  "overrides": {
    "vulnerable-package": "1.2.3"
  }
}
```

**Trade-off**: May miss future security patches.

#### Option 3: Replace Dependency

Find alternative package without vulnerability:

```bash
# Before
npm install vulnerable-package

# After
npm uninstall vulnerable-package
npm install secure-alternative
```

**Best for**: When multiple alternatives exist.

#### Option 4: Vendor and Patch

For critical dependencies:

```bash
# Fork upstream repository
gh repo fork upstream/vulnerable-package

# Apply security patch
git checkout -b fix/cve-2024-1234
# ... make fixes ...
git commit -m "fix: CVE-2024-1234"

# Use your fork
npm install github:yourorg/vulnerable-package#fix/cve-2024-1234
```

**Maintenance burden**: You own the patches.

### False Positives

**Scenario**: Scorecard flags vulnerability that doesn't affect your project.

#### Example 1: Vulnerability in Unused Code Path

```markdown
# CVE-2024-5678 in crypto-library

This vulnerability affects the `encrypt()` function. Our project only
uses the `hash()` function, making this CVE not applicable.

**Mitigation**: Code review confirms vulnerable code path is never executed.
**Tracking**: Waiting for upstream patch to eliminate alert.
```

#### Example 2: Development Dependency Only

```json
{
  "devDependencies": {
    "vulnerable-test-tool": "1.0.0"
  }
}
```

**Reality**: Development-only vulnerability doesn't affect production.

**Scorecard limitation**: May still flag it.

**Mitigation**: Document in README and accept lower score or fix anyway.

### Vulnerability Disclosure for Your Project

If **your project** has a vulnerability:

**Step 1**: Create GitHub Security Advisory

```text
Security tab → Advisories → New draft security advisory
```

**Step 2**: Work on private patch

```bash
# GitHub creates temporary private fork for you
git clone <temporary-fork-url>
git checkout -b fix/vulnerability
# ... develop fix ...
git push
```

**Step 3**: Request CVE (automatic through GitHub)

**Step 4**: Publish advisory and release patch

**Step 5**: Update SECURITY.md acknowledging reporter

### Troubleshooting

#### Dependabot PRs not auto-merging

**Check**: Do you have branch protection requiring reviews?

**Solution**: Configure branch protection to allow Dependabot auto-merge:

```yaml
# .github/workflows/dependabot-auto-merge.yml
name: Dependabot Auto-Merge

on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    if: github.actor == 'dependabot[bot]'
    runs-on: ubuntu-latest
    steps:
      - name: Auto-merge Dependabot PRs
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### Scorecard still shows vulnerabilities after fixing

**Check**: Did dependencies actually update?

```bash
# Verify fix is in lockfile
npm ls vulnerable-package
```

**Scorecard scan lag**: Can take 24 to 48 hours to reflect fixes.

**Clear cache**: Re-run Scorecard locally to verify fix:

```bash
docker run -e GITHUB_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
  --repo=github.com/your-org/your-repo \
  --checks=Vulnerabilities
```

#### Vulnerability in OS package, not application dependency

**Scenario**: Container base image has CVE.

**Solution**: Update base image:

```dockerfile
# Before
FROM ubuntu:20.04

# After
FROM ubuntu:24.04
```

Or use minimal base images:

```dockerfile
# Use distroless or alpine
FROM gcr.io/distroless/static-debian12
```

---


---

## Related Content

**Back to basics**:

- [Vulnerabilities Check](./vulnerabilities.md) - Core remediation guide

**Other Security Practices checks**:

- [Security-Policy](./security-policy.md) - Vulnerability disclosure process
- [CII-Best-Practices](./cii-best-practices.md) - OpenSSF Best Practices Badge

---

*Advanced vulnerability management handles edge cases: unfixable CVEs, false positives, and responsible disclosure.*
