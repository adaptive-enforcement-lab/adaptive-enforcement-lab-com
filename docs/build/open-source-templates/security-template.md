---
title: SECURITY.md Template
description: >-
  Production-ready SECURITY.md template with realistic SLAs, private disclosure mechanisms, and response timelines. Includes real example from OpenSSF-certified project.
tags:
  - open-source
  - templates
  - security
  - openssf
  - developers
---

# SECURITY.md Template

Production-ready SECURITY.md template with realistic SLAs and private disclosure mechanisms. Based on OpenSSF Best Practices Badge requirements.

!!! tip "Realistic SLAs"
    Template uses 48-hour initial response, 7-day updates, 90-day resolution targets. Better to under-promise and over-deliver than set unrealistic expectations.

---

## Template

```markdown
# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| [CURRENT_MAJOR].x   | :white_check_mark: |
| [PREVIOUS_MAJOR].x  | :white_check_mark: |
| < [PREVIOUS_MAJOR]  | :x:                |

## Reporting a Vulnerability

**Do NOT report security vulnerabilities through public GitHub issues.**

Use one of these private channels:

### GitHub Security Advisories (Preferred)

1. Go to the [Security tab](https://github.com/[ORG]/[PROJECT_NAME]/security/advisories)
2. Click "Report a vulnerability"
3. Fill out the advisory form

This creates a private discussion visible only to maintainers.

### Email

Send email to [SECURITY_EMAIL] with:

- **Subject**: `[SECURITY] Brief description`
- **Affected versions**: Which versions are vulnerable
- **Reproduction steps**: How to trigger the vulnerability
- **Impact assessment**: What an attacker could do
- **Suggested fix**: (Optional) Ideas for remediation

## Response Timeline

Realistic commitments we can actually meet:

- **Initial response**: Within 48 hours
- **Status update**: Within 7 days
- **Resolution target**: Within 90 days (varies by severity)

### Severity Levels

| Severity | Response Target | Patch Target |
|----------|-----------------|--------------|
| Critical | 24 hours | 7 days |
| High     | 48 hours | 14 days |
| Medium   | 1 week   | 30 days |
| Low      | 2 weeks  | 90 days |

**Note**: These are targets, not guarantees. Complex issues may take longer.

## Disclosure Policy

- **Coordinated disclosure**: We work with reporters to agree on disclosure timeline
- **Credit**: Security reporters are credited in release notes and advisories (unless they prefer anonymity)
- **CVE assignment**: We request CVEs for verified vulnerabilities

## Security Measures

This project employs:

- **Dependency scanning**: [Renovate|Dependabot] for automated updates
- **SAST**: [CodeQL|Semgrep|etc.] static analysis
- **SBOM**: Software Bill of Materials for all releases
- **Signed releases**: [Cosign|GPG] signatures on release artifacts
- **SLSA provenance**: Build attestations for supply chain security

See [Security Scanning](.github/workflows/security.yml) workflow for details.

## Bug Bounty

[If applicable]

We do not currently offer a bug bounty program. Security reports are greatly appreciated and credited.

[Or if you have one]

See our [Bug Bounty Policy](BOUNTY.md) for reward details.
```

---

## Real Example from readability Project

```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Do NOT report security vulnerabilities through public GitHub issues.**

### GitHub Security Advisories (Preferred)

1. [Security tab](https://github.com/adaptive-enforcement-lab/readability/security/advisories)
2. Click "Report a vulnerability"

### Email

Send to [security contact] with:

- Affected versions
- Reproduction steps
- Impact assessment
- Suggested fix (optional)

## Response Timeline

- **Initial response**: 48 hours
- **Status update**: 7 days
- **Resolution target**: 90 days (varies by severity)

## Security Measures

- **Renovate**: Automated dependency updates
- **CodeQL**: Static analysis
- **SBOM**: CycloneDX format for all releases
- **Cosign**: Keyless signing with Sigstore
- **SLSA Level 3**: Build provenance attestations
- **Trivy**: Container scanning
- **OpenSSF Scorecard**: Supply chain security checks
```

---

## Customization Tips

**Supported Versions**:

- Support current major version + previous major version
- For pre-1.0 projects, support only latest minor version
- Update table with each major release

**Response Timelines**:

- 48 hours is realistic for most maintainers
- 7-day updates keep reporters informed
- 90-day resolution target is achievable for most issues
- Critical issues deserve faster response (24 hours)

**Security Measures**:

List what you actually have, not what you plan to implement:

- Dependency scanning tools (Renovate, Dependabot)
- Static analysis (CodeQL, Semgrep, Snyk)
- SBOM generation (CycloneDX, SPDX)
- Release signing (Cosign, GPG)
- Build provenance (SLSA)
- Container scanning (Trivy, Grype)

---

## Related Patterns

- [Open Source Templates](index.md) - Main overview
- [CONTRIBUTING Template](contributing-template.md) - Contribution guidelines template
- [Issue Templates](issue-templates.md) - GitHub issue form templates

---

*SECURITY.md establishes trust. Private disclosure channels. Realistic SLAs. Security measures documentation. Copy this template. Set achievable timelines. Commit. OpenSSF Badge criterion satisfied.*
