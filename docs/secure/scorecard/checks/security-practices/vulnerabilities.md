---
description: >-
  Complete remediation guide for OpenSSF Scorecard Vulnerabilities check.
  Fix known CVEs and automate dependency security with Dependabot or Renovate.
tags:
  - scorecard
  - vulnerabilities
  - dependencies
  - cve
---

# Vulnerabilities Check

**Target**: 10/10 by fixing all known CVEs

**What it checks**: Whether repository has known security vulnerabilities in dependencies or code.

**Why it matters**: Known vulnerabilities are actively exploited by attackers. Public CVE databases make vulnerable projects easy targets.

### Understanding the Score

Scorecard checks:

- OSV (Open Source Vulnerabilities) database for known CVEs
- GitHub Security Advisories
- Language-specific vulnerability databases (npm audit, Go vulnerability DB, etc.)

**Scoring**:

- 10/10: No known vulnerabilities
- 7/10: Low severity vulnerabilities only
- 3/10: Medium severity vulnerabilities
- 0/10: High or critical vulnerabilities

**Detection scope**:

- Direct dependencies
- Transitive dependencies (dependencies of dependencies)
- Vulnerabilities in project code (if CVE assigned)

### Before: Vulnerable Dependencies

```bash
$ npm audit
found 3 vulnerabilities (1 moderate, 2 high)

Package: lodash
Severity: high
Dependency of: my-package
Path: my-package > some-tool > lodash
CVE: CVE-2024-1234
```

**Scorecard result**: Vulnerabilities 0/10

### After: Dependencies Updated

```bash
$ npm update
$ npm audit
found 0 vulnerabilities
```

**Scorecard result**: Vulnerabilities 10/10

### Automated Vulnerability Management

**Recommended**: Use Dependabot or Renovate for automatic vulnerability detection and patching.

#### GitHub Dependabot (Built-in)

Enable in repository settings:

```text
Settings → Security → Code security and analysis
  ✓ Dependency graph
  ✓ Dependabot alerts
  ✓ Dependabot security updates
```

**Result**: Dependabot automatically:

1. Detects vulnerable dependencies
2. Creates PRs with security updates
3. Alerts maintainers of new vulnerabilities

**Configuration** (optional `.github/dependabot.yml`):

```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "daily"
    open-pull-requests-limit: 10
```

#### Renovate (More Powerful)

Create `.github/renovate.json`:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "vulnerabilityAlerts": {
    "enabled": true,
    "labels": ["security"],
    "automerge": true,
    "automergeType": "pr",
    "assignees": ["@team/security"]
  },
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "matchCurrentVersion": "!/^0/",
      "automerge": true
    }
  ]
}
```

**Features**:

- Automatically merges security patches
- Batches non-security updates
- Cross-platform support (npm, pip, Go modules, etc.)

### Language-Specific Scanning

#### JavaScript / Node.js

```bash
# Audit dependencies
npm audit

# Fix automatically
npm audit fix

# See details
npm audit --json
```

**In CI**:

```yaml
- name: Audit dependencies
  run: npm audit --audit-level=moderate
```

**Result**: CI fails if moderate+ vulnerabilities found.

#### Go

```bash
# Scan for known vulnerabilities
go list -json -deps ./... | nancy sleuth

# Or use govulncheck
govulncheck ./...
```

**In CI**:

```yaml
- name: Scan for vulnerabilities
  run: |
    go install golang.org/x/vuln/cmd/govulncheck@latest
    govulncheck ./...
```

#### Python

```bash
# Audit dependencies
pip-audit

# Or use safety
safety check
```

**In CI**:

```yaml
- name: Audit dependencies
  run: |
    pip install pip-audit
    pip-audit
```

#### Rust

```bash
# Audit dependencies
cargo audit

# Fix vulnerable dependencies
cargo update
```

**In CI**:

```yaml
- name: Audit dependencies
  run: |
    cargo install cargo-audit
    cargo audit
```


---

## Advanced Topics

For handling unfixable vulnerabilities, false positives, and vulnerability disclosure, see:

**[Handling Complex Vulnerability Scenarios](./vulnerabilities-advanced.md)**

## Related Content

**Other Security Practices checks**:

- [Security-Policy](./security-policy.md) - Vulnerability disclosure process
- [CII-Best-Practices](./cii-best-practices.md) - OpenSSF Best Practices Badge
- [Fuzzing](./fuzzing.md) - Automated fuzz testing
- [Token-Permissions](./token-permissions.md) - GitHub Actions permission scoping

**Related guides**:

- [Scorecard Index](../../index.md) - Overview of all 18 checks
- [Tier 1 Progression](../../score-progression/tier-1.md) - Quick wins

---

*Vulnerabilities check is high-priority. Enable Dependabot and fix known CVEs immediately.*
