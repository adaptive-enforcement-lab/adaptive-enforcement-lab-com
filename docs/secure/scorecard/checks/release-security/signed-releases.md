---
description: >-
  Complete remediation guide for OpenSSF Scorecard Signed-Releases check.
  Achieve 10/10 with SLSA provenance using slsa-github-generator.
tags:

  - scorecard
  - slsa
  - provenance
  - signatures

---

# Signed-Releases Check

**Priority**: High (required for SLSA compliance)

**Advanced**: [Signed-Releases Advanced Guide](./release-security/signed-releases-advanced.md)

---

### [Packaging](./release-security/packaging.md)

**Target**: 10/10 by publishing to package registries

**What it checks**: Whether project is published to recognized package registries

**Why it matters**: Demonstrates wider distribution and established ecosystem integration

**Effort**: 1-2 hours

**Priority**: Medium (improves discoverability)

---

### [License](./release-security/license.md)

**Target**: 10/10 with OSI-approved license

**What it checks**: Whether repository contains OSI-approved open source license

**Why it matters**: Legal clarity for contributors and users

**Effort**: 5 minutes

**Priority**: High (quick win)

---

## Check Summary

| Check | Target | Effort | Priority | Weight |
| ----- | ------ | ------ | -------- | ------ |
| [License](./release-security/license.md) | 10/10 | 5 min | High | Low |
| [Packaging](./release-security/packaging.md) | 10/10 | 1-2 hrs | Medium | Low |
| [Signed-Releases](./release-security/signed-releases.md) | 10/10 | 2-4 hrs | High | High |

## Remediation Priority Order

**Order of implementation** for fastest improvement:

1. **License** (5 minutes) - Add LICENSE file
2. **Packaging** (1-2 hours) - Publish to package registry
3. **Signed-Releases** (2-4 hours) - Implement SLSA provenance

**Total estimated effort**: 3-6 hours for all three checks.

## Check Interactions

**Signed-Releases + Binary-Artifacts**:

SLSA provenance proves binaries were built from source in trusted environment.

**Packaging + Signed-Releases**:

Package registries often require signatures for publishing, making these complementary.

**License + CII-Best-Practices**:

OSI-approved license is required for OpenSSF Best Practices Badge.

## Check Categories

**Other check categories**:

- [Supply Chain Checks](./supply-chain.md) - Pinned-Dependencies, Dangerous-Workflow, Binary-Artifacts, SAST
- [Security Practices Checks](./security-practices.md) - Security-Policy, Vulnerabilities, Fuzzing
- [Code Review Checks](./code-review.md) - Code-Review, Contributors, Maintained

**Guides**:

- [Scorecard Index](../index.md) - Overview of all 18 checks
- [Tier 2 Progression](../score-progression/tier-2.md) - Medium complexity improvements
- [SLSA Provenance](../../../enforce/slsa-provenance/slsa-provenance.md) - Complete SLSA guide

## Next Steps

1. **Quick win**: Add LICENSE file (5 minutes)

2. **Publish package**: Set up package registry publishing (1-2 hours)

3. **SLSA provenance**: Implement slsa-github-generator (2-4 hours)

**Remember**: License is immediate. Packaging demonstrates maturity. Signed-Releases is required for SLSA compliance.

---

*Release security demonstrates supply chain integrity. Start with License, add Packaging for visibility, then implement Signed-Releases for provenance.*

---

## Advanced Topics

For troubleshooting, remediation steps, and advanced implementation patterns, see:

**[Signed-Releases Advanced Guide](./signed-releases-advanced.md)**

## Related Content

**Other Release Security checks**:

- [Packaging](./packaging.md) - Package registry publishing
- [License](./license.md) - OSI-approved license detection

**Related guides**:

- [Scorecard Index](../../index.md) - Overview of all 18 checks
- [SLSA Provenance](../../../../enforce/slsa-provenance/slsa-provenance.md) - Full SLSA guide

---

*Signed-Releases requires SLSA provenance for 10/10. Use slsa-github-generator with correct permissions and hash encoding.*
