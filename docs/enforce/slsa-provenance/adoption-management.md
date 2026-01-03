---
tags:
  - slsa
  - provenance
  - supply-chain
  - security
  - attestation
  - adoption
  - management
  - operators
  - security-teams
description: >-
  SLSA adoption management: team coordination, risk management strategies, pilot program design, and success metrics. Organizational playbook for rolling out SLSA at scale.
---

# SLSA Adoption Management Guide

Organizational strategies for rolling out SLSA at scale.

!!! info "Management Focus"
    **Team Coordination**: Roles, responsibilities, communication plans

    **Risk Management**: Rollback strategies, failure modes, mitigation

    **Pilot Programs**: Phased rollout, validation, lessons learned

    **Success Metrics**: Coverage tracking, quality indicators, ROI measurement

---

## Overview

Technical implementation is only half the battle. Successful SLSA adoption requires coordinated team effort, risk management, and measurable success criteria.

This guide covers the organizational aspects of SLSA adoption. For technical implementation steps, see [SLSA Adoption Roadmap](adoption-roadmap.md).

---

## Team Coordination

### Roles and Responsibilities

| Role | Phase 1 | Phase 2 | Phase 3 |
|------|---------|---------|---------|
| **Platform Engineer** | Create workflow | Configure permissions | Implement verification |
| **Security Engineer** | Define requirements | Audit provenance | Policy enforcement |
| **Developer** | Review changes | Test builds | Verify releases |
| **Release Manager** | Document process | Validate releases | Train team |

### Communication Plan

#### Phase 1 Kickoff

**Audience**: Engineering team

**Format**: Email announcement with 1-hour workshop

**Content**: SLSA basics, value proposition, implementation timeline

**Success metric**: 80% attendance at workshop

#### Phase 2 Transition

**Audience**: All teams with release responsibilities

**Format**: Slack announcement, updated release runbook, demo session

**Content**: GitHub attestation, verification commands, troubleshooting

**Success metric**: Zero release blockers from attestation changes

#### Phase 3 Rollout

**Audience**: Entire engineering organization

**Format**: All-hands presentation, updated documentation, hands-on training

**Content**: slsa-verifier usage, policy enforcement, OpenSSF Scorecard

**Success metric**: 100% of teams can verify provenance independently

### Training Requirements

#### Phase 1 Training: SLSA Fundamentals

**Duration**: 30 minutes

**Audience**: Platform engineers, security team

**Topics**:

- What is SLSA and why it matters
- Supply chain attack examples
- Provenance basics
- SLSA levels overview

**Materials**: Slide deck, threat model examples

**Assessment**: Quiz on SLSA levels and use cases

#### Phase 2 Training: Attestation and Verification

**Duration**: 1 hour

**Audience**: Release managers, developers

**Topics**:

- GitHub attestation workflow
- Using gh attestation verify command
- Troubleshooting permission errors
- Reading provenance files

**Materials**: Hands-on lab, troubleshooting guide

**Assessment**: Successfully verify a test release

#### Phase 3 Training: Level 3 Operations

**Duration**: 2 hours

**Audience**: All engineering teams

**Topics**:

- slsa-verifier tool usage
- Policy enforcement with Kyverno/OPA
- OpenSSF Scorecard interpretation
- Incident response for verification failures

**Materials**: Live demo, runbook, incident playbook

**Assessment**: Complete verification workflow end-to-end

---

## Risk Management

### Rollback Strategies

| Phase | Rollback Trigger | Rollback Action | Impact | Recovery Time |
|-------|-----------------|-----------------|--------|---------------|
| **Phase 1** | Provenance generation fails | Delete workflow file | None (no runtime dependencies) | 5 minutes |
| **Phase 2** | Attestation blocks releases | Revert to Phase 1 workflow | Lose service signing | 15 minutes |
| **Phase 3** | Build or verification failures | Revert to Phase 2 workflow | Lose SLSA Level 3 but keep Level 2 | 30 minutes |

### Common Failure Modes

#### Build failures after migration

**Symptoms**: Workflow runs fail, artifacts not uploaded

**Cause**: Permission changes break artifact upload or attestation generation

**Fix**: Restore original permissions, add required permissions incrementally

**Prevention**: Test on non-production branch first, validate permissions before merge

**Mitigation time**: 30 minutes to 2 hours

#### Verification always fails

**Symptoms**: slsa-verifier returns source mismatch error

**Cause**: Source URI doesn't match repository name exactly

**Fix**: Use exact repository name from gh repo view command

**Prevention**: Validate source URI in test release before production rollout

**Mitigation time**: 15 minutes

#### Performance degradation

**Symptoms**: Build times increase by 30+ seconds

**Cause**: Additional provenance generation overhead

**Fix**: Acceptable overhead, communicate expected slowdown

**Prevention**: Set expectations, optimize build steps where possible

**Mitigation time**: N/A (expected behavior)

#### OpenSSF Scorecard not updating

**Symptoms**: Score remains unchanged after Level 3 implementation

**Cause**: Scorecard updates run weekly, may take 24-48 hours

**Fix**: Wait for next scorecard run, verify provenance files exist

**Prevention**: Document expected delay, check provenance manually first

**Mitigation time**: 24-48 hours (automatic)

### Incident Response Playbook

#### Scenario: Production release blocked by verification failure

**Severity**: P1 (release blocker)

**Response**:

1. Identify which phase is failing (build, attestation, or verification)
2. Check recent workflow changes in git history
3. Validate artifact and provenance exist in release assets
4. Verify source URI matches repository exactly
5. If verification legitimately fails, investigate build compromise
6. If false positive, roll back to previous phase

**Escalation path**: Platform engineer → Security engineer → Engineering manager

**SLA**: 1 hour to resolution or rollback decision

---

## Pilot Programs and Metrics

For pilot program design, success metrics tracking, and ROI measurement, see [Adoption Metrics Guide](adoption-metrics.md).

---

## FAQ

**How do we prioritize which repositories to migrate first?** Start with public repositories and high-security services. Use OpenSSF Scorecard scores to identify candidates. See [Level Classification](level-classification.md) for decision framework.

**What if teams resist adopting SLSA?** Focus on value proposition (OpenSSF 10/10, compliance, security). Start with pilot volunteers, demonstrate success, then expand. Make it easy with templates and automation.

**How long should each phase run before moving forward?** 1-2 weeks validation minimum per phase. Don't rush. Failure to validate increases rollback risk.

**Who owns SLSA adoption long-term?** Platform engineering owns tooling and infrastructure. Security owns policy and compliance. Product teams own implementation for their services.

**How do we handle exceptions?** Document exception criteria (e.g., archived repos, internal tooling). Require security team approval. Track exceptions and revisit quarterly.

**What if we find a legitimate verification failure?** Treat as P1 incident. Investigate build environment, check for compromise, review recent changes. Do not bypass verification without security approval.

---

## Related Content

- **[SLSA Adoption Roadmap](adoption-roadmap.md)**: Technical implementation steps for Phases 1-3
- **[Level Classification](level-classification.md)**: Decision framework for target SLSA level
- **[Verification Workflows](verification-workflows.md)**: Implement verification gates
- **[Policy Templates](policy-templates.md)**: Enforce SLSA with Kyverno/OPA

---

*People, process, and technology. All three are required for successful SLSA adoption.*
