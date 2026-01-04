---
title: "OpenSSF Best Practices Badge in 2 Hours: The Documentation Gap"
date: 2025-12-17
authors:
  - mark
categories:
  - DevSecOps
  - Open Source
  - Quality Assurance
description: >-
  Earned OpenSSF Best Practices certification in 2 hours. The gap wasn't code quality. It was contributor documentation.
slug: openssf-badge-two-hours
---
# OpenSSF Best Practices Badge in 2 Hours: The Documentation Gap

Six pull requests. Two hours. OpenSSF Best Practices badge earned.

The readability project passed certification on December 13, 2025. But the work didn't start that day. It started months earlier when we built the infrastructure the badge measures.

<!-- more -->

---

## What We Already Had

Before touching the OpenSSF questionnaire, the project had:

### Test Coverage: 97-100%

| Package         | Coverage |
| ------------------ | ---------- |
| cmd/readability | 97.5%   |
| pkg/analyzer    | 99.1%   |
| pkg/config      | 100.0%  |
| pkg/markdown    | 98.8%   |
| pkg/output      | 99.6%   |

95% minimum enforced in CI. Race detector enabled. No exceptions.

**Security Scanning:**

- Trivy vulnerability scanning with SARIF output to GitHub Security
- CycloneDX SBOM generation uploaded as artifacts
- Dependabot watching dependencies
- Private vulnerability reporting enabled

**Code Quality:**

- golangci-lint with comprehensive ruleset including gosec
- Zero issues policy: every commit must pass
- gofmt enforcement
- Standard Go tooling (`go build`, `go test`)

**CI/CD:**

- Automated testing on every PR
- Release-Please for semantic versioning
- Git tags for all releases (v1.0.0 through v1.5.0)

Badge criteria: mostly already met. What was missing? **Contributor documentation.**

---

## The 2-Hour Documentation Sprint

**21:05**: PR #93 (CONTRIBUTING.md)

- Bug reporting process
- Feature request guidelines
- Development setup
- Code style requirements
- Testing requirements (95% threshold documented)

**21:17**: PR #94 (SECURITY.md)

- Supported versions table
- Private disclosure via GitHub Security Advisories
- Response timeline commitments:
  - Initial Response: Within 48 hours
  - Status Update: Within 7 days
  - Resolution Target: Within 90 days

**21:18**: PR #95 (Issue templates)

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- Config redirecting security issues to private reporting

**21:19**: PR #96 (Enable blank issues)

- Allow free-form alongside structured templates

**21:35**: PR #98 (TruffleHog CI integration)

- Secret scanning with `--only-verified` flag
- Added to existing security job

**21:42**: PR #99 (Badge in README)

- Display the certification

Done. Badge earned.

---

## The Lesson: Build First, Document Second

The OpenSSF badge measures what matters:

- Test coverage (we had it)
- Security scanning (already running)
- Static analysis (golangci-lint)
- Vulnerability response (Dependabot watching)
- Build system (standard Go tooling)

What it **also** measures: whether you tell contributors how to work with you.

CONTRIBUTING.md isn't bureaucracy. It's a contract: "Here's how we work. Here's what we expect."

SECURITY.md isn't compliance theater. It's a public commitment: "Report vulnerabilities here. We'll respond within 48 hours."

Issue templates aren't friction. They're structure that saves time for both sides.

---

## The Economics of Certification

**Cost**: 2 hours of documentation work

**Value**: Public signal that the project follows security best practices

For a well-maintained project, the badge is trivial to earn. For a poorly-maintained project, it exposes gaps that should be fixed anyway.

Either way, you win.

---

## Tactical Takeaways

1. **Build security infrastructure before you need a badge.** High coverage, scanning, and quality tools pay off regardless.

2. **Documentation is the certification gap.** Most projects have the practices. They just haven't documented them.

3. **GitHub's security features integrate perfectly.** Private reporting, Dependabot, security advisories. All free, all OpenSSF-aligned.

4. **N/A is valid.** Many criteria (especially cryptography) don't apply to all projects. Mark them N/A with explanation.

5. **Low effort, high signal.** For projects with good practices, certification is 2 hours of documentation.

!!! tip "Start With Infrastructure"

    Don't chase the badge first. Build the security infrastructure (testing, scanning, CI/CD), then document it. The badge becomes trivial when practices are already solid.

---

## The Badge

[![OpenSSF Best Practices](https://www.bestpractices.dev/projects/11610/badge)](https://www.bestpractices.dev/en/projects/11610)

View the full certification: [https://www.bestpractices.dev/en/projects/11610](https://www.bestpractices.dev/en/projects/11610)

Repository: [adaptive-enforcement-lab/readability](https://github.com/adaptive-enforcement-lab/readability)

---

## Beyond the Badge

The badge certifies the foundation. The journey continues:

- **[The Score That Wouldn't Move](2025-12-18-scorecard-stuck-at-eight.md)**: From signed releases (8/10) to cryptographic provenance (10/10)
- **[The Wall at 85%](2025-12-19-the-wall-at-eighty-five-percent.md)**: How refactoring unlocked 99% coverage
- **[Sixteen Alerts Overnight](2025-12-20-sixteen-alerts-overnight.md)**: OpenSSF Scorecard compliance in practice
- **[Zero-Vulnerability Pipelines](2025-12-15-zero-vulnerability-pipelines.md)**: Trivy, SBOM, and GitHub Security integration
