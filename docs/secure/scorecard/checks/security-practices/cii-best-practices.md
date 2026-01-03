---
description: >-
  Complete remediation guide for OpenSSF Scorecard CII-Best-Practices check.
  Earn OpenSSF Best Practices Badge to demonstrate security maturity.
tags:

  - scorecard
  - best-practices
  - certification

---

# CII-Best-Practices Check

!!! tip "Key Insight"
    CII Best Practices badge signals project maturity and security commitment.

**Target**: Passing or higher badge from OpenSSF

**What it checks**: Whether project has earned OpenSSF Best Practices Badge.

**Why it matters**: Badge certification demonstrates comprehensive security practices beyond what automated tools can check. Required for some enterprise procurement processes.

## Understanding the Score

Scorecard looks for:

- Badge URL in `README.md` from bestpractices.coreinfrastructure.org
- Badge status: passing, silver, or gold

**Scoring**:

- 10/10: Gold badge
- 7/10: Silver badge
- 5/10: Passing badge
- 0/10: No badge or badge in progress

**Important**: This is the **only** Scorecard check you can't automate. Requires human completion of questionnaire.

### Badge Levels

#### Passing Badge (5/10)

**Requirements** (60+ criteria):

- Basic project documentation
- Working build system
- Automated test suite
- Public version control
- Security vulnerability reporting process
- License clearly stated
- Basic security practices

**Time investment**: 2 to 4 hours to complete questionnaire and implement missing practices.

**Best for**: All open source projects

#### Silver Badge (7/10)

**Additional requirements**:

- Code review before merge
- Automated security analysis (SAST)
- Two-factor authentication for committers
- Signed releases
- Memory-safe language or memory safety analysis

**Time investment**: Additional 4 to 8 hours beyond passing badge.

**Best for**: Projects with active contributor base

#### Gold Badge (10/10)

**Additional requirements**:

- Formal security review
- Multiple organizations contributing
- Reproducible builds
- Security assurance case documentation

**Time investment**: Weeks to months of work.

**Best for**: Critical infrastructure projects

### Getting Started

**Step 1**: Sign up at [OpenSSF Best Practices](https://bestpractices.coreinfrastructure.org)

**Step 2**: Add your project

**Step 3**: Complete questionnaire

The questionnaire has 6 sections:

1. **Basics**: Project information and URLs
2. **Change Control**: Version control, issue tracking
3. **Reporting**: Security vulnerability reporting process
4. **Quality**: Testing, code review, build systems
5. **Security**: Security analysis, cryptography, input validation
6. **Analysis**: Static analysis, dynamic analysis

### Fast Track to Passing Badge

**Prerequisites** (must have before starting):

- Public GitHub repository
- README.md with project description
- LICENSE file
- Working CI/CD pipeline
- Test suite
- SECURITY.md file

**Questionnaire completion** (section by section):

#### Basics Section (15 minutes)

- Project name, description, URL
- Homepage URL
- Repository URL (make public)
- License identifier (SPDX)

**Tip**: Use choosealicense.com if you don't have a license.

#### Change Control (30 minutes)

- Public version control: ✓ (GitHub URL)
- Unique version numbering: ✓ (use semantic versioning)
- Version tags: ✓ (Git tags for releases)
- Changelog: Create `CHANGELOG.md`

**Quick changelog template**:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.0.0] - 2025-01-02

### Added

- Initial release

```bash
#### Reporting Section (20 minutes)

- Security vulnerability reporting: ✓ (point to SECURITY.md)
- Bug reporting: ✓ (GitHub Issues)
- Security point of contact: ✓ (email from SECURITY.md)

#### Quality Section (45 minutes)

- Automated test suite: ✓ (required)
- Statement of test coverage: ✓ (even if it's "We have tests for core functions")
- Continuous integration: ✓ (GitHub Actions workflow)
- Build warning policy: "We address all build warnings"
- Reproducible builds: "Builds are reproducible" (if using Go, this is usually true)

**Blocker**: If you don't have tests, add minimal test coverage:

```bash
# Go example

go test ./...

# Python example

pytest

# JavaScript example

npm test

```bash
Even minimal tests satisfy requirement.

#### Security Section (60 minutes)

- Secure development knowledge: "We follow secure coding practices"
- Memory safety: If using memory-safe language (Go, Python, JavaScript, Rust), check yes
- Static analysis: ✓ if you have CodeQL, Semgrep, or similar
- Dynamic analysis: Tests count as dynamic analysis
- Input validation: "We validate all external inputs"

**Tip**: Many questions ask if you "know" about security practices. Answer honestly but be aware of practices relevant to your stack.

#### Analysis Section (30 minutes)

- Static code analyzer: ✓ if using CodeQL, golangci-lint, Semgrep, etc.
- Warnings addressed: "We fix all warnings from static analysis"
- Memory safety analysis: If using Go/Rust/Python, yes (language provides memory safety)

**Total time**: 2 to 4 hours for passing badge.

### Badge Integration

Add badge to README.md:

```markdown
# My Project

[![OpenSSF Best Practices](https://www.bestpractices.coreinfrastructure.org/projects/12345/badge)](https://www.bestpractices.coreinfrastructure.org/projects/12345)

Project description here.

```bash
**Replace** `12345` with your project's badge ID.

**Result**: CII-Best-Practices 5/10 (passing badge)

### Common Blockers

#### "We don't have two-factor authentication enforcement"

**Passing badge**: Not required
**Silver badge**: Required for all committers

**Solution for silver**: Enable GitHub organization-level 2FA requirement:

```text
Organization Settings → Authentication security → Require two-factor authentication

```bash
#### "We don't have signed releases"

**Passing badge**: Not required
**Silver badge**: Required

**Solution**: See [Supply Chain Checks](./supply-chain.md) for Signed-Releases implementation.

#### "Static analysis shows too many warnings"

**Don't let perfection block completion**:

- You can answer "We have static analysis"
- Add comment: "We are working through existing warnings and prevent new ones"
- Badge accepts work-in-progress with forward progress

#### "We're a single maintainer"

**Passing badge**: Single maintainer is fine
**Silver/Gold badges**: May require multiple contributors

**Reality**: Solo projects can get passing badge. Silver/gold may not be realistic.

### Troubleshooting

#### Badge exists but Scorecard still shows 0/10

**Check**: Is badge URL in `README.md`?

**Check**: Is badge status "passing" or higher?

**Check**: Does badge project ID match your repository?

**Scorecard scan lag**: Can take 24 to 48 hours to update after badge earned.

#### Some questions don't apply to my project

**Use "N/A" or "Unmet" judiciously**:

- "Unmet" doesn't prevent badge if most criteria are met
- Some criteria have justification fields - use them
- Badge evaluates overall security posture, not 100% compliance

#### How long does review take?

**Self-certification**: Badge is immediately awarded when you complete questionnaire.

**No manual review** for passing badge.

**Silver/Gold badges**: May involve OpenSSF review for complex criteria.

---

---

## Related Content

**Other Security Practices checks**:

- [Security-Policy](./security-policy.md) - Vulnerability disclosure process
- [Vulnerabilities](./vulnerabilities.md) - Known CVE detection and remediation
- [Fuzzing](./fuzzing.md) - Automated fuzz testing
- [Token-Permissions](./token-permissions.md) - GitHub Actions permission scoping

**Related guides**:

- [Scorecard Index](../../index.md) - Overview of all 18 checks
- [Tier 1 Progression](../../score-progression/tier-1.md) - Quick wins

---

*CII-Best-Practices is the only Scorecard check requiring human completion. Budget 2-4 hours for passing badge.*
