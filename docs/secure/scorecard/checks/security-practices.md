---
description: >-
  Remediation playbooks for security practice checks including Security-Policy,
  CII-Best-Practices, Vulnerabilities, Fuzzing, and Token-Permissions.
tags:
  - scorecard
  - security
  - best-practices
---

# Security Practices Checks

!!! tip "Key Insight"
    Security practices demonstrate proactive vulnerability management.

Checks that measure security processes, documentation, and proactive security measures. These demonstrate security maturity beyond basic hygiene.

## Covered Checks

### [Security-Policy](./security-practices/security-policy.md)

**Target**: 10/10 by adding SECURITY.md file

**What it checks**: Documented vulnerability disclosure process

**Why it matters**: Security researchers need clear reporting instructions

**Effort**: 30 minutes

**Priority**: High (quick win)

---

### [CII-Best-Practices](./security-practices/cii-best-practices.md)

**Target**: Passing or higher badge from OpenSSF

**What it checks**: OpenSSF Best Practices Badge certification

**Why it matters**: Demonstrates comprehensive security practices beyond automation

**Effort**: 2-4 hours for passing badge

**Priority**: Medium (improves multiple checks at once)

---

### [Vulnerabilities](./security-practices/vulnerabilities.md)

**Target**: 10/10 by fixing all known CVEs

**What it checks**: Known security vulnerabilities in dependencies or code

**Why it matters**: Public CVE databases make vulnerable projects easy targets

**Effort**: 1 hour to enable automation

**Priority**: High (security critical)

**Advanced**: [Handling Complex Vulnerability Scenarios](./security-practices/vulnerabilities-advanced.md)

---

### [Fuzzing](./security-practices/fuzzing.md)

**Target**: 10/10 by integrating continuous fuzzing

**What it checks**: Automated fuzz testing to discover vulnerabilities

**Why it matters**: Finds edge cases and vulnerabilities that unit tests miss

**Effort**: 8+ hours (project-dependent)

**Priority**: Optional (only for projects handling untrusted input)

**Advanced**: [Advanced Fuzzing Techniques](./security-practices/fuzzing-advanced.md)

---

### [Token-Permissions](./security-practices/token-permissions.md)

**Target**: 10/10 by using job-level permission scoping

**What it checks**: GitHub Actions workflows grant minimal permissions per job

**Why it matters**: Limits blast radius if workflow is compromised

**Effort**: 1-2 hours

**Priority**: High (quick win)

---

## Check Summary

| Check | Target | Effort | Priority | Weight |
| ----- | ------ | ------ | -------- | ------ |
| [Security-Policy](./security-practices/security-policy.md) | 10/10 | 30 min | High | Medium |
| [Token-Permissions](./security-practices/token-permissions.md) | 10/10 | 1-2 hrs | High | High |
| [Vulnerabilities](./security-practices/vulnerabilities.md) | 10/10 | 1 hr | High | High |
| [CII-Best-Practices](./security-practices/cii-best-practices.md) | Passing+ | 2-4 hrs | Medium | Medium |
| [Fuzzing](./security-practices/fuzzing.md) | 10/10 | 8+ hrs | Optional | Medium |

## Remediation Priority

**Order of implementation** for fastest improvement:

1. **Security-Policy** (0.5 hours) - Add SECURITY.md file
2. **Token-Permissions** (1-2 hours) - Move permissions to job level
3. **Vulnerabilities** (1 hour) - Enable Dependabot, fix known CVEs
4. **CII-Best-Practices** (2-4 hours) - Complete badge questionnaire
5. **Fuzzing** (8+ hours or N/A) - Only if project handles untrusted input

**Total estimated effort**: 4.5-7.5 hours for first four checks. Fuzzing is optional and project-dependent.

## Check Interactions

**Security-Policy + Vulnerabilities**:

SECURITY.md documents how researchers report vulnerabilities. Vulnerabilities check shows if you're fixing them.

**CII-Best-Practices + Multiple Checks**:

Badge questionnaire covers many Scorecard checks. Achieving passing badge often improves 5+ other Scorecard checks simultaneously.

**Token-Permissions + Dangerous-Workflow**:

Job-level permissions reduce blast radius if dangerous workflow is exploited. Defense in depth.

**Vulnerabilities + Dependency-Update-Tool**:

Automated dependency updates (Renovate/Dependabot) prevent new vulnerabilities from accumulating.

**Fuzzing + SAST + Vulnerabilities**:

Three complementary security layers:

- **SAST**: Finds vulnerabilities in source code
- **Fuzzing**: Finds crashes and edge cases via execution
- **Vulnerabilities**: Finds known CVEs in dependencies

## Related Content

**Other check categories**:

- [Supply Chain Checks](./supply-chain.md) - Pinned-Dependencies, Dangerous-Workflow, Binary-Artifacts, SAST
- [Code Review Checks](./code-review.md) - Code-Review, Contributors, Maintained
- [Branch Protection Checks](./branch-protection.md) - Branch-Protection
- [Release Security Checks](./release-security.md) - Signed-Releases, Packaging

**Guides**:

- [Scorecard Index](../index.md) - Overview of all 18 checks
- [Tier 1 Progression](../score-progression/tier-1.md) - Quick wins
- [Scorecard Compliance](../scorecard-compliance.md) - Detailed patterns

**Blog posts**:

- [OpenSSF Badge in 2 Hours](../../../blog/posts/2025-12-17-openssf-badge-two-hours.md) - Fast-track CII-Best-Practices
- [16 Alerts Cleared Overnight](../../../blog/posts/2025-12-20-sixteen-alerts-overnight.md) - Token-Permissions mass fix

## Next Steps

1. **Quick scan**: Run Scorecard to get baseline for these checks

   ```bash
   docker run -e GITHUB_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
     --repo=github.com/your-org/your-repo \
     --checks=Security-Policy,CII-Best-Practices,Vulnerabilities,Fuzzing,Token-Permissions
   ```

2. **Immediate wins**: Add SECURITY.md and fix Token-Permissions (1-2 hours total)

3. **Dependency security**: Enable Dependabot, fix known vulnerabilities (1 hour)

4. **Badge certification**: Complete OpenSSF Best Practices questionnaire (2-4 hours)

5. **Fuzzing evaluation**: Decide if fuzzing adds value for your project (project-dependent)

**Remember**: Security-Policy and Token-Permissions are high-impact quick wins. CII badge is time-consuming but improves multiple checks at once. Fuzzing is optional unless your project handles untrusted input.

---

*Security practices demonstrate maturity beyond basic hygiene. Start with documentation (Security-Policy), fix permission scoping (Token-Permissions), then pursue comprehensive certification (CII badge).*
