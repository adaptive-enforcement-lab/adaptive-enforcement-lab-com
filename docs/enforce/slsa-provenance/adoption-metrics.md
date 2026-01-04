---
title: SLSA Adoption Metrics and Pilot Programs
tags:
  - slsa
  - provenance
  - supply-chain
  - security
  - attestation
  - metrics
  - roi
  - operators
  - security-teams
description: >-
  SLSA adoption metrics and pilot programs: track coverage, quality, and verification success. Measure ROI with security improvements, compliance benefits, and operational efficiency gains.
---
# SLSA Adoption Metrics and Pilot Programs

Measure success and demonstrate value of SLSA adoption.

!!! info "Metrics Focus"
    **Pilot Programs**: Phased rollout with validation gates

    **Coverage Metrics**: Track adoption across organization

    **Quality Metrics**: Measure SLSA level distribution

    **ROI Measurement**: Quantify security and business value

---

## Overview

Successful SLSA adoption requires measurable progress and clear demonstration of value. This guide covers pilot program design, success metrics, and ROI measurement.

**Also see**: [Adoption Roadmap](adoption-roadmap.md) for technical implementation and [Adoption Management](adoption-management.md) for team coordination.

---

## Pilot Program Strategy

### Phase 1 Pilot: Build Documentation

**Scope**: 1-2 non-critical repositories

**Duration**: 1 week

**Participants**: Platform engineering team (2-3 engineers)

**Success criteria**:

- [ ] Provenance generated for 100% of builds
- [ ] Team comfortable with provenance concept
- [ ] Documentation complete and reviewed
- [ ] Zero blockers identified

**Lessons learned documentation**:

- Common questions from team
- Permission issues encountered
- Documentation gaps
- Training material updates needed

**Go/no-go decision**: End of week review, must have zero blockers

### Phase 2 Pilot: Service-Signed Provenance

**Scope**: 3-5 repositories including one production service

**Duration**: 2 weeks

**Participants**: Platform team + 2 product teams (6-8 engineers)

**Success criteria**:

- [ ] Attestation verification works for all pilot repos
- [ ] No release blockers
- [ ] Permission patterns documented
- [ ] Runbook validated by product teams

**Lessons learned documentation**:

- Permission issues and resolutions
- Team feedback on verification UX
- Troubleshooting patterns
- Integration with existing release process

**Go/no-go decision**: End of week 2, requires sign-off from product team leads

### Phase 3 Pilot: SLSA Level 3

**Scope**: All repositories with external releases (10-20 repos)

**Duration**: 3-4 weeks

**Participants**: All engineering teams with release responsibilities

**Success criteria**:

- [ ] SLSA Level 3 provenance for all pilot repos
- [ ] OpenSSF Scorecard shows 10/10
- [ ] Verification workflows passing
- [ ] Team trained and confident
- [ ] Incident response playbook validated

**Lessons learned documentation**:

- Migration path refinements
- Verification workflow optimizations
- Policy enforcement feedback
- Training effectiveness

**Go/no-go decision**: End of week 4, requires engineering leadership approval

---

## Success Metrics Dashboard

### Coverage Metrics

Track what percentage of repositories have SLSA provenance:

```bash
# Total repositories in organization
TOTAL_REPOS=$(gh repo list --limit 1000 --json name -q 'length')

# Repositories with SLSA provenance (tagged)
SLSA_REPOS=$(gh api /orgs/<org>/repos | \
  jq '[.[] | select(.topics[]? | contains("slsa"))] | length')

# Calculate coverage percentage
COVERAGE=$((SLSA_REPOS * 100 / TOTAL_REPOS))
echo "SLSA Coverage: $COVERAGE%"
```

**Target**: 80% coverage for public repositories, 60% for private

**Tracking frequency**: Weekly

**Dashboard**: Create GitHub issue or wiki page tracking progress

### Quality Metrics

Track SLSA level distribution across organization:

```bash
# Repositories using Level 3 (slsa-github-generator)
LEVEL3=$(gh api /search/code?q=slsa-github-generator+org:<org> | \
  jq '.total_count')

# Repositories using Level 2 (GitHub attestation)
LEVEL2=$(gh api /search/code?q=attest-build-provenance+org:<org> | \
  jq '.total_count')

echo "Level 3: $LEVEL3 repositories"
echo "Level 2: $LEVEL2 repositories"
echo "Ratio: $((LEVEL3 * 100 / (LEVEL3 + LEVEL2)))% at Level 3"
```

**Target**: 70% of repos at Level 3, 30% at Level 2

**Tracking frequency**: Biweekly

**Goal**: Prioritize Level 3 for public repos and high-security services

### Verification Metrics

Track verification workflow success rate:

```bash
# Successful verifications in last 30 days
gh api /repos/<org>/<repo>/actions/workflows/verify-slsa.yml/runs \
  --field created=">=$(date -d '30 days ago' +%Y-%m-%d)" | \
  jq '[.workflow_runs[] | select(.conclusion == "success")] | length'

# Failed verifications
gh api /repos/<org>/<repo>/actions/workflows/verify-slsa.yml/runs \
  --field created=">=$(date -d '30 days ago' +%Y-%m-%d)" | \
  jq '[.workflow_runs[] | select(.conclusion == "failure")] | length'

# Calculate success rate
# Success rate = successful / (successful + failed) * 100
```

**Target**: 95% verification success rate

**Tracking frequency**: Daily

**Alert**: Notify security team if success rate drops below 90%

### OpenSSF Scorecard Metrics

Track improvement in supply chain security scores:

```bash
# Check OpenSSF Scorecard for organization repos
for repo in $(gh repo list <org> --limit 100 --json name -q '.[].name'); do
  SCORE=$(gh api /repos/<org>/$repo/community/profile 2>/dev/null | \
    jq -r '.health_percentage // "N/A"')
  echo "$repo: $SCORE"
done
```

**Target**: 90% of repositories at 10/10 scorecard

**Tracking frequency**: Weekly

**Note**: Scorecard updates may lag 24-48 hours after SLSA implementation

### Time-to-Detection Metrics

Measure how quickly supply chain issues are detected:

| Scenario | Without SLSA | With SLSA L2 | With SLSA L3 |
|----------|--------------|--------------|--------------|
| **Build tampering** | Days to weeks | Hours | Minutes |
| **Source mismatch** | Weeks | Hours | Minutes |
| **Compromised artifact** | Post-incident | Audit trail | Real-time block |

**Target**: Under 5 minutes detection for build integrity issues

**Measurement**: Track time from issue to detection in incidents

---

## ROI Measurement

### Cost Analysis

**Implementation costs (one-time)**:

- Platform engineering time: 40-60 hours per phase (3 phases = 120-180 hours)
- Training and documentation: 20-30 hours
- Pilot program coordination: 10-15 hours per phase (30-45 hours total)
- **Total**: 170-255 engineer hours

**Ongoing costs (per year)**:

- Build time overhead: 30-60 seconds per build (acceptable, minimal cost)
- Verification workflow runtime: 1-2 minutes per release (negligible)
- Maintenance and updates: 5-10 hours per quarter (20-40 hours/year)
- **Total**: 20-40 engineer hours per year

### Value Delivered

**Security improvements**:

- Tamper-evident builds preventing undetected artifact modification
- Build source verification ensuring artifact-to-source linkage
- Attack class prevention blocking build infrastructure compromise
- **Quantifiable**: Reduced supply chain attack surface

**Compliance benefits**:

- SOC 2 Type II evidence through automated provenance generation
- ISO 27001 controls demonstrating build integrity
- FedRAMP requirements satisfying supply chain security mandates
- **Quantifiable**: Reduced audit findings, faster compliance certification

**Operational efficiency**:

- Automated provenance generation eliminating manual documentation
- Incident response acceleration from days to minutes
- Audit preparation simplification with readily available provenance
- **Quantifiable**: Hours saved per incident, faster audit cycles

### Business Impact

**Risk reduction**:

- Supply chain attack detection capability
- Regulatory compliance posture improvement
- Customer trust and transparency enhancement
- **Value**: Prevented breaches, avoided compliance penalties

**Quantifiable metrics**:

- OpenSSF Scorecard improvement from 8/10 to 10/10
- Audit finding reduction by 2-3 findings per audit cycle
- Incident response time reduction from hours/days to minutes
- **Value**: Measurable security posture improvement

### Cost-Benefit Summary

| Category | Cost | Benefit | ROI Timeline |
|----------|------|---------|--------------|
| **Implementation** | 170-255 hours | Baseline security posture | 6-12 months |
| **Ongoing** | 20-40 hours/year | Continuous protection | Immediate |
| **Compliance** | Included | Audit efficiency gain | Per audit cycle |
| **Incident Response** | Included | Time reduction (days → minutes) | Per incident |

**Break-even**: Typically 1-2 audit cycles or 1 prevented incident

---

## Reporting Dashboard Template

Create a weekly/monthly dashboard tracking these metrics:

### SLSA Adoption Dashboard

**Week ending**: YYYY-MM-DD

**Coverage**:

- Total repos: 150
- SLSA L3: 45 (30%)
- SLSA L2: 60 (40%)
- No SLSA: 45 (30%)
- **Target**: 80% coverage by Q2

**Quality**:

- Verification success rate: 96% (target: 95%)
- OpenSSF 10/10: 40 repos (target: 90% of SLSA repos)
- Failed verifications: 2 (investigated, resolved)

**Progress**:

- Pilot Phase: 3 complete
- Repositories migrated this week: 5
- Training sessions: 2 (12 engineers trained)

**Blockers**: None

**Next steps**: Expand to remaining public repositories

---

## FAQ

**How do we track metrics at scale?** Automate metric collection with GitHub API scripts. Run weekly and publish to internal dashboard or GitHub wiki.

**What if verification success rate drops?** Investigate failures immediately. Common causes are workflow misconfigurations or legitimate build issues. Set up alerts at 90% threshold.

**How do we prioritize repositories for pilot?** Start with non-critical repos (Phase 1), add production services (Phase 2), then expand to all external releases (Phase 3). Use OpenSSF scores to identify candidates.

**What ROI do we present to leadership?** Focus on compliance efficiency (audit findings reduction), incident response acceleration (days to minutes), and risk reduction (supply chain attack prevention).

**How long until we see ROI?** Immediate security benefit. Compliance ROI visible in next audit cycle (3-12 months). Incident response ROI realized per incident.

---

## Related Content

- **[Adoption Roadmap](adoption-roadmap.md)**: Technical implementation for Phases 1-3
- **[Adoption Management](adoption-management.md)**: Team coordination and risk management
- **[Phase 3 Implementation](adoption-phase3.md)**: SLSA Level 3 details
- **[Policy Templates](policy-templates.md)**: Enforce SLSA with Kyverno/OPA

---

*Measure what matters. Track progress. Demonstrate value. Build organizational buy-in through data.*
