---
tags:
  - slsa
  - provenance
  - supply-chain
  - security
  - attestation
  - build-integrity
  - decision-trees
  - developers
  - operators
  - security-teams
description: >-
  SLSA level classification decision trees: determine your target SLSA level based on security requirements, runner configuration, and compliance needs. Includes self-hosted runner evaluation.
---

# SLSA Level Classification: Decision Trees

Determine the right SLSA level for your security posture and infrastructure.

!!! info "Quick Classification"
    **GitHub-hosted runners** = SLSA Level 3 achievable

    **Self-hosted persistent runners** = SLSA Level 2 maximum

    **Self-hosted ephemeral runners** = SLSA Level 3 achievable

    **Compliance requirement** = Usually SLSA Level 3

## Overview

SLSA level selection depends on three factors:

1. **Security requirements** - What attack classes must you prevent?
2. **Infrastructure capabilities** - What does your build environment support?
3. **Compliance mandates** - What do auditors require?

This guide provides decision trees for each scenario.

## Decision Tree: Requirements-Based Classification

Start here to determine your target SLSA level based on security and compliance needs:

```mermaid
graph TD
    Start[What SLSA level do you need?] --> Q1{OpenSSF Scorecard 10/10 required?}
    Q1 -->|Yes| Level3[Target: SLSA Level 3]
    Q1 -->|No| Q2{Compliance framework mandate?}

    Q2 -->|Yes| Q3{Framework requires provenance?}
    Q3 -->|Yes| Level3
    Q3 -->|No| Q4{SBOM sufficient?}
    Q4 -->|Yes| Level1[Target: SLSA Level 1]
    Q4 -->|No| Level3

    Q2 -->|No| Q5{High-security application?}
    Q5 -->|Yes| Q6{Build tampering in threat model?}
    Q6 -->|Yes| Level3
    Q6 -->|No| Level2[Target: SLSA Level 2]

    Q5 -->|No| Q7{Want audit trail?}
    Q7 -->|Yes| Level2
    Q7 -->|No| Q8{Starting SLSA journey?}
    Q8 -->|Yes| Level1
    Q8 -->|No| Level0[Level 0: No SLSA]

    %% Ghostty Hardcore Theme
    style Start fill:#65d9ef,color:#1b1d1e
    style Level3 fill:#a7e22e,color:#1b1d1e
    style Level2 fill:#ffd866,color:#1b1d1e
    style Level1 fill:#fc9867,color:#1b1d1e
    style Level0 fill:#f92572,color:#1b1d1e

```

**Key decision factors**: OpenSSF 10/10 requires Level 3 (non-negotiable). Compliance frameworks (SOC 2, ISO 27001, FedRAMP) often mandate provenance. High-security applications (payment, auth, infrastructure) benefit from Level 3 isolation. If build tampering is in your threat model, choose Level 3.

## Decision Tree: Runner Configuration Classification

Use this tree to determine the maximum SLSA level your current infrastructure supports:

```mermaid
graph TD
    Start[What runners do you use?] --> Q1{GitHub-hosted or self-hosted?}

    Q1 -->|GitHub-hosted| GH1[ubuntu-latest, macos-latest, etc.]
    GH1 --> GH2[Maximum Level: SLSA 3]
    GH2 --> GH3{Want Level 4?}
    GH3 -->|Yes| GH4[Requires hermetic build tools]
    GH3 -->|No| GH5[Use slsa-github-generator]

    Q1 -->|Self-hosted| SH1{Ephemeral or persistent?}

    SH1 -->|Ephemeral| SH2{VM destroyed after each job?}
    SH2 -->|Yes| SH3{No state persists between jobs?}
    SH3 -->|Yes| SH4[Maximum Level: SLSA 3]
    SH3 -->|No| SH5[Maximum Level: SLSA 2]
    SH2 -->|No| SH5

    SH1 -->|Persistent| SH6{Shared between jobs?}
    SH6 -->|Yes| SH7[Maximum Level: SLSA 2]
    SH6 -->|No| SH8{Developer access to runner?}
    SH8 -->|Yes| SH9[Maximum Level: SLSA 1]
    SH8 -->|No| SH7

    %% Ghostty Hardcore Theme
    style Start fill:#65d9ef,color:#1b1d1e
    style GH2 fill:#a7e22e,color:#1b1d1e
    style SH4 fill:#a7e22e,color:#1b1d1e
    style SH5 fill:#ffd866,color:#1b1d1e
    style SH7 fill:#ffd866,color:#1b1d1e
    style SH9 fill:#fc9867,color:#1b1d1e

```

**Critical questions**: Ephemeral (fresh VM per job, destroyed after) vs Persistent (same VM for multiple jobs). State isolation: Can jobs access previous job artifacts? Developer access: Can devs SSH to runners or modify configuration?

## Decision Tree: Self-Hosted Runner Evaluation

Detailed classification for self-hosted runner environments:

```mermaid
graph TD
    Start[Self-Hosted Runner Evaluation] --> Q1{Runner provisioning method?}

    Q1 -->|Kubernetes with fresh pods| K8s1{Pod destroyed after job?}
    K8s1 -->|Yes| K8s2{No persistent volumes?}
    K8s2 -->|Yes| Level3[SLSA Level 3 Achievable]
    K8s2 -->|No| Level2[SLSA Level 2 Maximum]
    K8s1 -->|No| Level2

    Q1 -->|VM autoscaling group| VM1{VM created per job?}
    VM1 -->|Yes| VM2{VM deleted after job?}
    VM2 -->|Yes| VM3{No shared storage?}
    VM3 -->|Yes| Level3
    VM3 -->|No| Level2
    VM2 -->|No| Level2
    VM1 -->|No| VM4{Jobs run sequentially on same VM?}
    VM4 -->|Yes| Level2
    VM4 -->|No| VM5[Check isolation mechanisms]

    Q1 -->|Dedicated physical/VM| Ded1{Single job then rebuilt?}
    Ded1 -->|Yes| Ded2{Automated image rebuild?}
    Ded2 -->|Yes| Level3
    Ded2 -->|No| Level2
    Ded1 -->|No| Ded3{Multiple jobs on same host?}
    Ded3 -->|Yes| Level2
    Ded3 -->|No| Level1[SLSA Level 1 Maximum]

    Q1 -->|Docker-in-Docker| DinD1{Container removed after job?}
    DinD1 -->|Yes| DinD2{Host OS shared?}
    DinD2 -->|Yes| Level2
    DinD2 -->|No| DinD3[Container isolation not sufficient for Level 3]
    DinD1 -->|No| Level2

    %% Ghostty Hardcore Theme
    style Start fill:#65d9ef,color:#1b1d1e
    style Level3 fill:#a7e22e,color:#1b1d1e
    style Level2 fill:#ffd866,color:#1b1d1e
    style Level1 fill:#fc9867,color:#1b1d1e
    style DinD3 fill:#ffd866,color:#1b1d1e

```

**Runner evaluation**: Kubernetes fresh pods achieve Level 3 (pod-per-job, no persistent volumes). VM autoscaling achieves Level 3 (VM-per-job, destroyed after). Dedicated runners max at Level 2 unless automated rebuild after each job. Docker-in-Docker max Level 2 (shared kernel/host OS).

## Classification Matrix

Quick reference for common scenarios:

| Runner Configuration | Isolation Level | Maximum SLSA Level | Notes |
|---------------------|-----------------|-------------------|-------|
| GitHub-hosted (ubuntu-latest) | Isolated | **Level 3** | Recommended |
| GitHub-hosted (self-hosted label) | Depends | Varies | Verify runner type |
| Kubernetes ephemeral pods | Isolated | **Level 3** | No persistent volumes |
| Kubernetes persistent pods | Shared | **Level 2** | Pod reused across jobs |
| AWS EC2 autoscaling | Isolated | **Level 3** | If VM-per-job |
| GCP Compute autoscaling | Isolated | **Level 3** | If VM-per-job |
| Azure VM scale sets | Isolated | **Level 3** | If VM-per-job |
| Docker-in-Docker | Shared kernel | **Level 2** | Host OS shared |
| Persistent VM | Shared | **Level 2** | Sequential jobs |
| Developer workstation | No isolation | **Level 1** | Manual provenance |

## Compliance-Driven Classification

Different compliance frameworks have different SLSA requirements:

```mermaid
graph TD
    Start[Compliance Requirement] --> Q1{Which framework?}

    Q1 -->|OpenSSF Scorecard| OSF1[Requirement: SLSA Level 3]
    OSF1 --> OSF2[Must have .intoto.jsonl files]

    Q1 -->|SOC 2| SOC1{Type I or Type II?}
    SOC1 -->|Type I| SOC2[SLSA Level 2 sufficient]
    SOC1 -->|Type II| SOC3[SLSA Level 3 recommended]

    Q1 -->|ISO 27001| ISO1[SLSA Level 2 minimum]
    ISO1 --> ISO2{High-risk system?}
    ISO2 -->|Yes| ISO3[SLSA Level 3 recommended]
    ISO2 -->|No| ISO4[Level 2 sufficient]

    Q1 -->|FedRAMP| Fed1{Impact level?}
    Fed1 -->|Moderate| Fed2[SLSA Level 3 recommended]
    Fed1 -->|High| Fed3[SLSA Level 3 required]
    Fed1 -->|Low| Fed4[SLSA Level 2 sufficient]

    Q1 -->|PCI DSS| PCI1[Level 2 minimum for audit trail]
    PCI1 --> PCI2{Payment processing?}
    PCI2 -->|Yes| PCI3[Level 3 recommended]
    PCI2 -->|No| PCI4[Level 2 sufficient]

    %% Ghostty Hardcore Theme
    style Start fill:#65d9ef,color:#1b1d1e
    style OSF1 fill:#f92572,color:#1b1d1e
    style SOC3 fill:#a7e22e,color:#1b1d1e
    style ISO3 fill:#a7e22e,color:#1b1d1e
    style Fed3 fill:#f92572,color:#1b1d1e
    style PCI3 fill:#a7e22e,color:#1b1d1e

```

**OpenSSF Scorecard**: Level 3 required for 10/10. **SOC 2**: Type I accepts Level 2, Type II benefits from Level 3. **ISO 27001**: Level 2 demonstrates compliance, Level 3 exceeds. **FedRAMP**: Moderate/High expect Level 3. **PCI DSS**: Level 2 audit trail, Level 3 recommended for payment processing.

## Migration Decision Tree

Use this when planning migration from current state to target SLSA level:

```mermaid
graph TD
    Start[Current SLSA Level] --> Q1{What level are you at now?}

    Q1 -->|Level 0| L0_1{Want to start SLSA?}
    L0_1 -->|Yes| L0_2[Quick win: Add Level 1 provenance]
    L0_2 --> L0_3[1-2 days effort]
    L0_3 --> L0_4{Then jump to Level 3?}
    L0_4 -->|Yes| L0_5[If using GitHub-hosted runners]
    L0_4 -->|No| L0_6[Stop at Level 2 with self-hosted]

    Q1 -->|Level 1| L1_1{Using CI/CD?}
    L1_1 -->|Yes| L1_2[Upgrade to Level 2: Automate provenance]
    L1_2 --> L1_3[1 week effort]
    L1_1 -->|No| L1_4[Implement CI/CD first]

    Q1 -->|Level 2| L2_1{Using GitHub-hosted runners?}
    L2_1 -->|Yes| L2_2[Upgrade to Level 3: slsa-github-generator]
    L2_2 --> L2_3[2-3 weeks with verification]
    L2_1 -->|No| L2_4{Can migrate to ephemeral runners?}
    L2_4 -->|Yes| L2_5[Plan infrastructure migration]
    L2_4 -->|No| L2_6[Stay at Level 2]

    %% Ghostty Hardcore Theme
    style Start fill:#65d9ef,color:#1b1d1e
    style L0_5 fill:#a7e22e,color:#1b1d1e
    style L2_2 fill:#a7e22e,color:#1b1d1e
    style L2_6 fill:#ffd866,color:#1b1d1e

```

## Common Scenarios

| Scenario | Runner Type | Target Level | Rationale |
|----------|-------------|--------------|-----------|
| **Startup with GitHub Actions** | GitHub-hosted | Level 3 | OpenSSF 10/10, minimal complexity, 2-3 weeks |
| **Enterprise self-hosted** | Persistent VMs | Level 2 | Cannot migrate, audit trail sufficient, plan ephemeral migration |
| **Open source project** | GitHub-hosted | Level 3 | Free runners, OpenSSF badge, 1 week implementation |
| **Financial services** | Ephemeral | Level 3 | FedRAMP/PCI compliance, build tampering detection required |
| **Internal tooling** | Any | Level 1-2 | Low-security, basic audit trail, no compliance mandate |

## Upgrade Path

| From | To | Effort | Key Changes |
|------|-----|--------|-------------|
| **Level 0 → 1** | 1-2 days | Document build, record source commit, manual provenance | No infrastructure changes |
| **Level 1 → 2** | 1 week | Automate provenance, service signing, CI/CD integration | Requires CI/CD pipeline |
| **Level 2 → 3** | 2-3 weeks | Isolated builds, slsa-github-generator, verification workflows | **Requires GitHub-hosted or ephemeral runners** |

## Decision Tree: When to Stop at Level 2

Not every project needs Level 3. Use this tree to determine if Level 2 is sufficient:

```mermaid
graph TD
    Start[Should I stop at Level 2?] --> Q1{OpenSSF Scorecard 10/10 required?}
    Q1 -->|Yes| No1[No, need Level 3]
    Q1 -->|No| Q2{Self-hosted runners required?}

    Q2 -->|Yes| Q3{Can migrate to ephemeral?}
    Q3 -->|No| Yes1[Yes, stop at Level 2]
    Q3 -->|Yes| Q4{Worth migration effort?}
    Q4 -->|No| Yes1
    Q4 -->|Yes| No2[No, upgrade to Level 3]

    Q2 -->|No| Q5{Build tampering in threat model?}
    Q5 -->|Yes| No3[No, need Level 3]
    Q5 -->|No| Q6{Compliance requires isolation?}
    Q6 -->|Yes| No4[No, need Level 3]
    Q6 -->|No| Q7{Low-security application?}
    Q7 -->|Yes| Yes2[Yes, Level 2 sufficient]
    Q7 -->|No| Q8{Want maximum assurance?}
    Q8 -->|Yes| No5[No, upgrade to Level 3]
    Q8 -->|No| Yes3[Yes, Level 2 is pragmatic choice]

    %% Ghostty Hardcore Theme
    style Start fill:#65d9ef,color:#1b1d1e
    style Yes1 fill:#ffd866,color:#1b1d1e
    style Yes2 fill:#ffd866,color:#1b1d1e
    style Yes3 fill:#ffd866,color:#1b1d1e
    style No1 fill:#a7e22e,color:#1b1d1e
    style No2 fill:#a7e22e,color:#1b1d1e
    style No3 fill:#a7e22e,color:#1b1d1e
    style No4 fill:#a7e22e,color:#1b1d1e
    style No5 fill:#a7e22e,color:#1b1d1e

```

## Key Takeaways

**Most organizations target Level 3**: Strong security without Level 4 complexity, achieves OpenSSF 10/10, satisfies most compliance frameworks.

**GitHub-hosted runners simplify everything**: Automatic Level 3 isolation, no infrastructure management, free for public repos.

**Self-hosted runners require careful evaluation**: Persistent runners max out at Level 2, ephemeral runners can achieve Level 3.

**Compliance often drives requirements**: OpenSSF Scorecard mandates Level 3, FedRAMP expects Level 3, SOC 2 accepts Level 2.

**Level 2 is pragmatic for many scenarios**: Provides service-generated provenance, doesn't require infrastructure changes, sufficient for audit trail.

## FAQ

**Can I skip Level 1 and 2 and go directly to Level 3?** Yes, if using GitHub-hosted runners. The levels are cumulative in requirements but not in implementation path.

**My self-hosted runners claim to be isolated. How do I verify?** Check if VM is destroyed after each job, no state persists, and no shared storage. If uncertain, assume Level 2.

**What if I need Level 3 but can't migrate from self-hosted runners?** Implement ephemeral runner infrastructure (Kubernetes with fresh pods, VM autoscaling with per-job instances).

**Does Level 2 satisfy compliance requirements?** Depends on framework. SOC 2 and ISO 27001 accept Level 2. OpenSSF Scorecard and FedRAMP Moderate expect Level 3.

**How long does Level 2 to Level 3 upgrade take?** 2-3 weeks including infrastructure changes, verification workflows, and policy updates. Longer if migrating runner infrastructure.

## Related Content

- **[SLSA Levels Explained](slsa-levels.md)**: Detailed requirements for each level
- **[SLSA Implementation Playbook](index.md)**: Complete adoption guide
- **[Current SLSA Implementation](slsa-provenance.md)**: Level 3 workflow patterns
- **[OpenSSF Scorecard](../../secure/scorecard/scorecard-compliance.md)**: SLSA impact on scores
*Classification determines feasibility. Requirements determine necessity. Infrastructure determines timeline. Start with honest assessment of all three.*
