## Branch-Protection: Admin Bypass Allowed

**Current score**: 9/10
**Target score**: 10/10

**Status**: Temporary exception, planned remediation

**Reason**: Small team (3 developers, all admins). Current structure doesn't
support separation of admin vs. developer roles.

**Mitigation**:

- Emergency bypass procedure documented in SECURITY.md
- All bypasses logged in `.github/EMERGENCY-BYPASSES.md`
- Monthly audit of bypass usage
- Bypass count (last 12 months): 2

**Remediation plan**:

- **2026-02-01**: Hire additional developer
- **2026-03-01**: Restructure teams (2 admins, 2 developers)
- **2026-03-15**: Enable `enforce_admins = true`
- **2026-04-01**: Verify 10/10 score

**References**:

- Team structure: `docs/team.md` (example path in your repository)
- Emergency bypass log: `.github/EMERGENCY-BYPASSES.md` (example path in your repository)

---

## Fuzzing: Not Applicable

**Current score**: 0/10
**Target score**: 0/10 (not applicable)

**Status**: Permanent exception

**Reason**: Static documentation site with no application code. No untrusted
input processing, no binary parsing, no network services.

**Alternative controls**:

- Markdown linting (markdownlint)
- Link validation (automated checks)
- Dependency scanning (Renovate + Dependabot)

**Reassessment trigger**: If dynamic content generation is added

**Review frequency**: Annually

**Next review**: 2027-01-02

---

## CII-Best-Practices: Private Repository

**Current score**: 0/10
**Target score**: 0/10 (not applicable)

**Status**: Permanent exception

**Reason**: Private repository. OpenSSF Best Practices badge requires public projects.

**Alternative controls**:
We implement equivalent practices without the badge:

- Security policy (SECURITY.md)
- Vulnerability disclosure process
- Automated testing and SAST
- Code review requirements
- Dependency scanning

**Reassessment trigger**: If repository becomes public

**Review frequency**: N/A

---

## Review Process

**Frequency**: Quarterly (January, April, July, October)

**Process**:

1. Review each exception for continued relevance
2. Update status and scores
3. Evaluate new Scorecard releases for changed recommendations
4. Update target scores based on current threat model
5. Commit changes to this document

**Responsible**: Security team (@security-team)

**Escalation**: Exceptions older than 12 months require CISO approval

---

## Change Log

| Date | Check | Change | Reason |
|------|-------|--------|--------|
| 2026-01-02 | All | Initial documentation | Baseline exception tracking |
| 2025-12-15 | Branch-Protection | Added remediation plan | Team expansion approved |

```bash
---

## Cross-References

**Related guides**:

- [False Positives Guide](false-positives.md) - Identify tool limitations vs. real issues
- [Supply Chain Checks](checks/supply-chain.md) - Detailed Pinned-Dependencies guidance
- [Security Practices Checks](checks/security-practices.md) - CII badge fast-track
- [Score Progression](score-progression.md) - Prioritized remediation roadmap

**External resources**:

- [OpenSSF Scorecard Checks](https://github.com/ossf/scorecard/blob/main/docs/checks.md)
- [SLSA Framework](https://slsa.dev/)
- [CII Best Practices](https://bestpractices.coreinfrastructure.org/)

---

**Bottom line**: Make security decisions based on your threat model, not Scorecard's score. Document your reasoning. Review periodically. A well-reasoned 8/10 with documented exceptions demonstrates more security maturity than a blind 10/10.
