---
title: Implementation Roadmap - Execution Guide
description: >-
  Track progress, verify audit readiness, plan rollbacks, estimate costs,
  and measure success metrics for SDLC hardening rollout.
---

# Implementation Roadmap - Execution Guide

## Progress Tracking

### Month 1 Checklist

- [ ] Branch protection on all production branches
- [ ] Required status checks (tests, lint)
- [ ] GitHub App created and first PAT replaced
- [ ] Evidence archive workflow running
- [ ] First month's evidence collected

### Month 2 Checklist

- [ ] Secrets detection (pre-commit + CI)
- [ ] Signed commits required on protected branches
- [ ] SBOM generation in all build pipelines
- [ ] All PATs migrated to GitHub Apps
- [ ] License compliance checks passing

### Month 3 Checklist

- [ ] Vulnerability scanning blocks HIGH/CRITICAL
- [ ] Kyverno deployed with core policies
- [ ] Audit simulation completed successfully
- [ ] Gaps remediated
- [ ] Team trained on controls
- [ ] Runbook documented

---

## Audit Readiness Criteria

System is audit-ready when all criteria met:

- ✅ Branch protection enforced (`enforce_admins: true`)
- ✅ Required status checks configured and passing
- ✅ GitHub Apps replace all PATs
- ✅ Pre-commit hooks deployed org-wide
- ✅ Signed commits required
- ✅ SBOM generation integrated
- ✅ Vulnerability scanning blocks merges
- ✅ Kyverno enforces runtime policies
- ✅ Evidence archive running (3+ months of data)
- ✅ Exception process documented
- ✅ Runbook complete

---

## Rollback Plan

If controls cause unacceptable friction:

### Temporary Disable

```bash
# Disable branch protection temporarily
gh api --method DELETE repos/org/repo/branches/main/protection

# Re-enable after issue resolved
gh api --method PUT repos/org/repo/branches/main/protection \
  --input protection-config.json
```

**Critical**: Log every disable. Include reason and duration.

### Gradual Rollout

If org-wide deployment causes issues:

1. Start with pilot repository (non-critical)
2. Expand to team repositories (1 team at a time)
3. Monitor for friction and remediate
4. Roll out to all repositories after validation

---

## Cost Estimation

| Item | Monthly Cost |
| ------ | ------------- |
| GitHub Actions minutes (increased by CI checks) | +$50 |
| GCS storage (evidence archive, 3 years) | $5 |
| Kyverno deployment (cluster resources) | $10 |
| Pre-commit tool licenses | $0 (open source) |
| **Total** | **~$65/month** |

ROI: Avoided audit findings, faster compliance certification, reduced security incidents.

---

## Success Metrics

Track monthly:

```yaml
sdlc_hardening_metrics:
  pre_commit_blocks: 15           # Secrets caught
  ci_vulnerability_blocks: 8      # HIGH CVEs blocked
  unsigned_commits_rejected: 3    # Branch protection enforced
  prs_without_review: 0           # Zero exceptions
  kyverno_policy_violations: 12   # Runtime blocks
  sbom_coverage: 100%             # All images have SBOMs
```

Green numbers = controls working.

---

## Common Objections

### "This slows down development"

Slowdowns happen when controls catch real issues. That's the goal.

Fast merges with vulnerabilities cost more than slow merges with validation.

### "We trust our developers"

Auditors don't trust anybody. They trust systems.

Controls protect developers from mistakes and prove diligence when incidents happen.

### "Emergency hotfixes need exceptions"

Fine. Document the exception. Log the bypass. Require post-merge review.

Show auditors: "Bypass used 3 times in 2024. All reviewed within 24 hours."

Not: "We bypass whenever it's convenient."

---

## Related Resources

- **[Phased Rollout](index.md)** - 90-day implementation plan
- **[Branch Protection](../branch-protection.md)** - Month 1, Week 1
- **[Status Checks](../status-checks/index.md)** - Month 1, Week 2
- **[GitHub Apps](../github-apps/index.md)** - Month 1, Week 3
- **[Pre-commit Hooks](../pre-commit-hooks.md)** - Month 2, Week 5
- **[Commit Signing](../commit-signing.md)** - Month 2, Week 6
- **[SBOM Generation](../sbom-generation.md)** - Month 2, Week 7
- **[Audit Evidence](../audit-evidence.md)** - Month 1, Week 4; Month 3, Week 11

---

*Checklist tracked. Audit criteria met. Rollback planned. Costs estimated. Metrics green. System hardened.*
