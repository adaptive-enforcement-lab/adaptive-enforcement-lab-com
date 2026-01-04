---
title: Fuzzing Assessment
description: >-
  Evaluate fuzzing investment ROI based on codebase complexity, user input handling, and security risk tolerance for your organization.
---
# Fuzzing Assessment

!!! tip "Key Insight"
    Fuzzing ROI depends on codebase complexity and risk tolerance.

## Fuzzing Assessment

**Status**: Not implemented
**Scorecard impact**: 0/10 for Fuzzing check

**Rationale**:
This project is a static documentation site built with MkDocs Material.
There is no application code that processes untrusted input.

**Alternative security measures**:

- **Input validation**: N/A - no user input processing
- **Static analysis**: markdownlint enforces content standards
- **Dependency scanning**: Renovate + GitHub Dependabot
- **SAST**: Not applicable (no application code)

**Reassessment trigger**:
If dynamic content generation or user-submitted content is added,
fuzzing will be re-evaluated.

**Decision date**: 2026-01-02
**Next review**: 2026-07-01

```bash
### When to Implement Fuzzing

If you parse untrusted input, invest in fuzzing:

```yaml
# .github/workflows/fuzzing.yml

name: Fuzzing

on:
  schedule:

    - cron: '0 2 * * *'  # Nightly

  workflow_dispatch:

jobs:
  fuzz:
    runs-on: ubuntu-latest
    steps:

      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Build fuzzers

        run: make build-fuzzers

      - name: Run fuzzing (4 hours)

        run: |
          # ClusterFuzzLite for GitHub Actions
          timeout 14400 ./fuzz-targets/parser-fuzz || true

      - name: Upload crash artifacts

        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: fuzzing-crashes
          path: crash-*

```bash
**Time investment**: 1-3 days initial setup, ongoing CI time cost.

---

## Controversial Check: CII-Best-Practices

**Recommendation**: Earn OpenSSF Best Practices badge.

**Controversy**: Significant time investment (6-20 hours) for questionnaire.

### Decision Matrix

| Project Context | Pursue Badge | Skip Badge | Rationale |
|-----------------|--------------|------------|-----------|
| **Public OSS library** used by many | ✅ Yes | ❌ | Community trust signal, worth the time |
| **Enterprise compliance** requirement | ✅ Yes | ❌ | Procurement requirement, mandatory |
| **Public OSS tool** (niche audience) | ⚠️ Maybe | ⚠️ Maybe | Evaluate user base and impact |
| **Private repository** | ❌ | ✅ Skip | Badge requires public project |
| **Internal tooling** | ❌ | ✅ Skip | No external users to signal to |
| **Documentation site** | ❌ | ✅ Skip | Questionnaire doesn't apply |

### Fast-Track: Earning the Badge Efficiently

If you decide to pursue the badge, see our [fast-track guide](../checks/security-practices.md).

**Time estimates**:

- **Passing level**: 2-4 hours (answer questions, link to existing docs)
- **Silver level**: 8-12 hours (additional documentation and process)
- **Gold level**: 20+ hours (comprehensive security program)

**Most projects stop at Passing** - it signals good practices without gold-plating.

### Skipping the Badge

If you skip CII-Best-Practices, document which practices you follow:

```markdown
# SECURITY.md

## Security Practices

While we don't pursue the OpenSSF Best Practices badge (Scorecard: 0/10),
we implement these equivalent controls:

**Project oversight**:

- [x] Public version control (GitHub)
- [x] Public issue tracker
- [x] SECURITY.md with vulnerability reporting

**Change control**:

- [x] Require 2 reviewers for main branch
- [x] All status checks must pass
- [x] CODEOWNERS enforce security team review

**Continuous integration**:

- [x] Automated tests on every PR
- [x] SAST via CodeQL
- [x] Dependency scanning via Dependabot
- [x] SLSA provenance for releases

**Security knowledge**:

- [x] Security point of contact documented
- [x] Threat model maintained
- [x] Incident response process defined

**Why no badge**:
This is an internal tool with no external users. The questionnaire process
(6-8 hours) provides no security benefit beyond the practices we already follow.

**Decision date**: 2026-01-02

```bash
---

## Controversial Check: Auto-Merge for Dependencies

**Recommendation**: Human review for all code changes (affects Code-Review score).

**Controversy**: Auto-merge for dependency updates vs. human review creates trade-offs.

### The Trade-Off

```text
Human Review Required:
✅ Code-Review score: 10/10
✅ Human verification of changes
❌ Slower security patch deployment
❌ Review fatigue for automated updates
❌ Stale dependencies when PRs pile up

Auto-Merge Enabled:
❌ Code-Review score: 8/10
✅ Fast security patch deployment
✅ Dependencies stay current
✅ CI verification instead of human review
❌ No human eyes on changes

```bash
### Decision Matrix

| Update Type | Human Review | Auto-Merge | Rationale |
|-------------|--------------|------------|-----------|
| **Major version** updates | ✅ Required | ❌ | Breaking changes likely |
| **Minor version** updates | ⚠️ Depends | ⚠️ Depends | Evaluate based on package |
| **Patch version** updates | ❌ | ✅ Auto-merge | Bug fixes only, low risk |
| **Security patches** | ❌ | ✅ Auto-merge | Speed matters more than review |
| **Dev dependencies** | ❌ | ✅ Auto-merge | Not in production, CI verifies |

### Recommended Pattern: Tiered Auto-Merge

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "packageRules": [
    {
      "description": "Auto-merge patch updates for production dependencies",
      "matchUpdateTypes": ["patch"],
      "matchDepTypes": ["dependencies"],
      "automerge": true,
      "automergeType": "pr",
      "platformAutomerge": true,
      "ignoreTests": false
    },
    {
      "description": "Auto-merge all updates for dev dependencies",
      "matchUpdateTypes": ["patch", "minor"],
      "matchDepTypes": ["devDependencies"],
      "automerge": true
    },
    {
      "description": "Require approval for major updates",
      "matchUpdateTypes": ["major"],
      "dependencyDashboardApproval": true,
      "automerge": false
    },
    {
      "description": "Fast-track security patches",
      "matchUpdateTypes": ["patch"],
      "matchDatasources": ["npm"],
      "vulnerabilityAlerts": {
        "enabled": true
      },
      "automerge": true,
      "platformAutomerge": true
    }
  ]
}

```bash
**Result**:

- Security patches: Auto-merged within hours
- Patch updates: Auto-merged after CI passes
- Minor updates: Require approval for production deps
- Major updates: Always require human review

**Scorecard impact**: Expect 8-9/10 for Code-Review instead of 10/10.

**Security posture**: Better than 10/10 with slow manual reviews that create stale dependencies.

---

## Controversial Check: SAST for Unsupported Languages

**Recommendation**: Run static application security testing.

**Controversy**: Scorecard only recognizes mainstream SAST tools.

### Decision Matrix

| Language/Framework | Mainstream SAST Available | Action |
|--------------------|---------------------------|--------|
| JavaScript/TypeScript | ✅ CodeQL, Semgrep | Implement CodeQL |
| Python | ✅ CodeQL, Semgrep, Bandit | Implement CodeQL |
| Go | ✅ CodeQL, Semgrep, gosec | Implement CodeQL |
| Java | ✅ CodeQL, Semgrep, SpotBugs | Implement CodeQL |
| Ruby | ✅ CodeQL, Brakeman | Implement CodeQL |
| Rust | ⚠️ Clippy (not recognized by Scorecard) | Run Clippy, accept low score |
| Shell scripts | ⚠️ ShellCheck (not recognized) | Run ShellCheck, accept 0/10 |
| Markdown/docs | ❌ Not applicable | Accept 0/10 |
| Terraform/HCL | ⚠️ tflint, checkov (not recognized) | Run linters, accept low score |

### Documentation Template: Language-Specific SAST

```markdown
# SECURITY.md

## Static Analysis

**Scorecard SAST check**: 0/10

**Reason**: This project uses Rust. Scorecard does not recognize `cargo clippy`
as a SAST tool, though it serves the same purpose.

**Implemented tooling**:

- **Clippy** (Rust linter with security checks)
  - Runs on every PR
  - Configured with `#![deny(clippy::all)]`
  - Security-specific lints enabled

- **Cargo audit** (dependency vulnerability scanner)
  - Checks for known CVEs in dependencies
  - Runs daily in CI

- **Rustfmt** (code formatting)
  - Enforces consistent style
  - Prevents common bugs from inconsistent formatting

**CI enforcement**:

    ```yaml
    # .github/workflows/security.yml

    - name: Clippy (Rust SAST)

      run: cargo clippy --all-targets --all-features -- -D warnings

    - name: Cargo audit (dependency CVEs)

      run: cargo audit

    ```bash
**Decision**: Accept 0/10 Scorecard score. Our SAST implementation is equivalent
to CodeQL for other languages, but Scorecard doesn't recognize Rust-specific tools.

**Escalation path**: If Scorecard adds Clippy recognition, we're already compliant.

**Decision date**: 2026-01-02
**Review date**: 2026-07-01

```bash
---

## Documentation Template: Comprehensive Exceptions

Create `.github/SCORECARD-EXCEPTIONS.md` to document all intentional deviations:

```markdown
# OpenSSF Scorecard Exceptions

This document explains intentional deviations from Scorecard recommendations.

**Last updated**: 2026-01-02
**Review frequency**: Quarterly
**Next review**: 2026-04-01

---

## Summary

| Check | Current Score | Target Score | Status | Review Date |
|-------|---------------|--------------|--------|-------------|
| Pinned-Dependencies | 9/10 | 9/10 | Accepted | 2026-04-01 |
| Branch-Protection | 9/10 | 10/10 | Planned | 2026-03-01 |
| Fuzzing | 0/10 | 0/10 | Not Applicable | 2027-01-01 |
| CII-Best-Practices | 0/10 | 0/10 | Not Applicable | N/A |

**Overall score**: 8.2/10
**Target score**: 8.5/10

---

## Pinned-Dependencies: Version Tag Exceptions

**Current score**: 9/10
**Target score**: 9/10 (accept exception)

### ossf/scorecard-action

**Status**: Intentional permanent exception

**Reason**: Action validates its own workflow identity using version tags.
SHA pinning causes authentication failures.

**Mitigation**:

- Action maintained by OpenSSF (trusted source)
- Renovate monitors for new versions
- Manual review process for updates

**References**:

- [Scorecard Action Issue #1234](https://github.com/ossf/scorecard-action/issues/1234)
- Internal decision: `docs/adr/0042-scorecard-action-version-tags.md` (example ADR path in your repository)

**Review frequency**: Annually

---
