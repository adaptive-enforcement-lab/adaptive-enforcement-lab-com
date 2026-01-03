---
description: >-
  Complete remediation guide for OpenSSF Scorecard Security-Policy check.
  Add SECURITY.md with clear vulnerability disclosure process.
tags:
  - scorecard
  - security
  - vulnerability-disclosure
---

# Security-Policy Check

!!! tip "Key Insight"
    Security policies guide responsible vulnerability disclosure.

**Target**: 10/10 by adding SECURITY.md file

**What it checks**: Whether repository has a documented security vulnerability disclosure policy.

**Why it matters**: Security researchers need to know how to responsibly report vulnerabilities. Without clear disclosure process, researchers may publicly disclose vulnerabilities without giving you time to patch.

## Understanding the Score

Scorecard looks for:

- `SECURITY.md` file in repository root or `.github/`
- Security policy in repository settings (GitHub's security tab)
- Security contact in `README.md` with clear reporting instructions

**Scoring**:

- 10/10: SECURITY.md exists with clear reporting instructions
- 0/10: No security policy found

## Before: No Security Policy

```bash
$ ls -la
README.md
LICENSE
src/
tests/
```

**Risk**: Security researchers don't know how to report vulnerabilities. May result in public disclosure or no disclosure at all.

## After: SECURITY.md in Place

Create `SECURITY.md` in repository root:

```markdown
# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 2.x     | :white_check_mark: |
| 1.x     | :x:                |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Do not open public issues for security vulnerabilities.**

To report a security vulnerability, please use one of the following methods:

### 1. GitHub Security Advisories (Preferred)

1. Go to the Security tab in this repository
2. Click "Report a vulnerability"
3. Fill out the advisory form with details

This creates a private discussion where we can coordinate disclosure.

### 2. Email Security Team

Email: security@example.com

Include the following information:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

### Response Timeline

- **Initial response**: Within 48 hours
- **Status update**: Within 7 days
- **Fix timeline**: Depends on severity
  - Critical: 7 days
  - High: 14 days
  - Medium: 30 days
  - Low: 90 days

### Disclosure Policy

We follow coordinated disclosure:

1. You report vulnerability privately
2. We confirm and investigate
3. We develop and test fix
4. We release patched version
5. We publish security advisory
6. You receive credit in advisory (if desired)

We aim to disclose within 90 days of report.

### Security Acknowledgments

We appreciate responsible disclosure. Security researchers who report valid vulnerabilities will be:

- Credited in security advisory (if desired)
- Listed in SECURITY.md acknowledgments
- Considered for bug bounty (if program is active)

Thank you for helping keep this project secure.
```

**Result**: Security-Policy 10/10

## Minimal Template

For smaller projects, a minimal policy works:

```markdown
# Security Policy

## Reporting a Vulnerability

To report a security vulnerability:

1. **Do not open a public issue**
2. Email: security@example.com
3. Include description, steps to reproduce, and potential impact

We will respond within 48 hours and coordinate private disclosure.
```

**Still achieves**: Security-Policy 10/10

## GitHub Security Advisories

Enable GitHub's built-in security features:

**Navigate to**: Settings → Security → Code security and analysis

**Enable**:

- ✓ Dependency graph
- ✓ Dependabot alerts
- ✓ Dependabot security updates
- ✓ Private vulnerability reporting

**Result**: Researchers can use GitHub's private reporting workflow without needing email.

## Security Contact in README

Alternative approach (less common):

Add to `README.md`:

```markdown
## Security

For security vulnerabilities, please contact security@example.com.
Do not open public issues for security concerns.
```

**Scorecard detection**: May work, but `SECURITY.md` is more reliable.

## Bug Bounty Programs

For mature projects, include bug bounty information:

```markdown
## Bug Bounty

We operate a bug bounty program for security researchers.

- **Platform**: HackerOne / Bugcrowd / Direct
- **Scope**: All components in this repository
- **Rewards**: $100 to $10,000 depending on severity
- **Details**: https://example.com/bug-bounty

Submit reports through the platform for bounty consideration.
```

## Troubleshooting

### SECURITY.md exists but not detected

**Check**: Is file named exactly `SECURITY.md` (case-sensitive)?

**Check**: Is file in repository root or `.github/` directory?

```bash
# Correct locations

./SECURITY.md
./.github/SECURITY.md

# Incorrect (not detected)

./docs/SECURITY.md
./security.md
./SECURITY.txt
```

### What if we don't have a security team?

**Solo maintainer pattern**:

```markdown
# Security Policy

## Reporting a Vulnerability

To report a security vulnerability, email: your-email@example.com

I will respond within 72 hours and work with you to coordinate disclosure.

This is a solo-maintained project. Response times may vary, but security
issues are my top priority.
```

**Community pattern**:

```markdown
# Security Policy

## Reporting a Vulnerability

This is a community-maintained project. To report vulnerabilities:

1. Use GitHub Security Advisories (Security tab → Report a vulnerability)
2. Tag maintainers: @maintainer1 @maintainer2
3. We will respond within 1 week

We coordinate disclosure through GitHub Security Advisories.
```

### Should I include PGP key?

**Optional but recommended** for high-sensitivity projects:

Add to your `SECURITY.md`:

```text
## Encrypted Communication

For highly sensitive reports, use PGP encryption:

-----BEGIN PGP PUBLIC KEY BLOCK-----

[Your PGP public key]

-----END PGP PUBLIC KEY BLOCK-----

Fingerprint: ABCD 1234 EFGH 5678 IJKL 9012 MNOP 3456 QRST 7890
```

---

## Related Content

**Other Security Practices checks**:

- [CII-Best-Practices](./cii-best-practices.md) - OpenSSF Best Practices Badge
- [Vulnerabilities](./vulnerabilities.md) - Known CVE detection and remediation
- [Fuzzing](./fuzzing.md) - Automated fuzz testing
- [Token-Permissions](./token-permissions.md) - GitHub Actions permission scoping

**Related guides**:

- [Scorecard Index](../../index.md) - Overview of all 18 checks
- [Tier 1 Progression](../../score-progression/tier-1.md) - Quick wins including Security-Policy

---

*Security-Policy is a 30-minute quick win. Add SECURITY.md to establish clear vulnerability reporting process.*
