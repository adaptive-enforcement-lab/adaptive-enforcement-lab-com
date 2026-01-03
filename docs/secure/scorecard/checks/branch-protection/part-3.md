---
description: >-
  Prioritize Branch-Protection fixes with dependency updates and protection rules. Quick wins achieve passing scores in 1.5-2.5 hours total effort.
---

# Remediation Priority

!!! tip "Key Insight"
    Prioritize Branch-Protection fixes based on repository criticality and team capacity.

## Remediation Priority

**Order of implementation** for fastest score improvement:

1. **Dependency-Update-Tool** (0.5 hours) - Add Renovate or Dependabot config
2. **Branch-Protection** (1 to 2 hours) - Configure branch protection with all required settings

**Total estimated effort**: 1.5 to 2.5 hours for both checks.

**Quick win**: Add Dependabot config first (10 minutes), then configure branch protection while waiting for Scorecard to rescan.

---

## Check Interactions

**Branch-Protection + Code-Review**:

Branch protection enforces code review requirements. These two checks measure the same control from different angles:

- **Branch-Protection**: Configuration exists
- **Code-Review**: Configuration is actually being followed (checks commit history)

**Dependency-Update-Tool + Vulnerabilities**:

Automated updates prevent vulnerabilities from accumulating. Projects with active dependency updates score higher on Vulnerabilities check because known CVEs are patched faster.

**Dependency-Update-Tool + Pinned-Dependencies**:

Renovate auto-pins GitHub Actions to SHA digests, directly improving Pinned-Dependencies score. Dependabot does not pin by default.

**Branch-Protection + Dangerous-Workflow**:

Branch protection prevents attackers from merging malicious workflow changes directly. Requires PR review even for `.github/workflows/*.yml` files.

**Branch-Protection + Maintained**:

Active branch protection signals ongoing maintenance. Abandoned projects often have disabled or weakened branch protection.

---

## Related Content

**Existing guides**:

- [Scorecard Index](../../index.md) - Overview of all 18 checks
- [Code Review Checks](../code-review.md) - Code-Review check details with branch protection patterns
- [Supply Chain Checks](../supply-chain.md) - Pinned-Dependencies automated management with Renovate
- [Security Practices Checks](../security-practices.md) - Vulnerabilities check and dependency scanning
- [Tier 1 Progression](../../score-progression/tier-1.md) - Quick wins including basic branch protection
- [Tier 2 Progression](../../score-progression/tier-2.md) - Advanced branch protection with up-to-date branches

**Blog posts**:

- [Stuck at 8: The Journey to 10/10](../../../../blog/posts/2025-12-18-scorecard-stuck-at-eight.md) - Branch protection "up to date" requirement
- [16 Alerts Cleared Overnight](../../../../blog/posts/2025-12-20-sixteen-alerts-overnight.md) - Mass remediation patterns

**Related patterns**:

- [Scorecard Workflow Examples](../../scorecard-workflow-examples.md) - Complete workflows with status checks referenced in branch protection
- [Scorecard Compliance](../../scorecard-compliance.md) - Core patterns for achieving 10/10 scores
