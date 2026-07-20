---
title: Roadmap
description: >-
  What's coming to Adaptive Enforcement Lab. Blog content, resources,
  deep dives, and community features in development.
date: 2025-11-25
---

# Roadmap

Adaptive Enforcement Lab is actively building. Here's what's shipped and what's coming.

---

## Recently Shipped

!!! success "Claude Code Skills Marketplace (July 2026)"

    **117 skills, generated from these docs, delivered into the agent**

    The documentation on this site now compiles into Claude Code skills. Same markdown source, different delivery mechanism — patterns arrive at the moment code is written instead of waiting to be searched for.

    - ✅ **[claude-skills marketplace](https://github.com/adaptive-enforcement-lab/claude-skills)** - `v1.0.x`, four plugin collections
    - ✅ **Patterns** (38 skills) - Error handling, idempotency, work avoidance, resilience, architecture
    - ✅ **Secure** (33 skills) - GitHub Actions hardening, GKE, supply chain, OIDC federation
    - ✅ **Enforce** (34 skills) - Kyverno, OPA, policy-as-code, SDLC hardening roadmap
    - ✅ **Build** (12 skills) - Go CLI architecture, release pipelines, packaging, versioned docs
    - ✅ **Automated generation** - Go extraction pipeline, clean/hexagonal architecture, release-please versioning
    - ✅ **Continuous sync** - Skills regenerate on documentation change; source and skills cannot drift

    **Story:** [The Docs Nobody Read](blog/posts/2026-07-21-docs-nobody-read.md)

!!! success "Major Content Release (January 2026)"

    **Comprehensive Security & DevOps Content Pipeline**

    ### Enforce Section

    **[4-Phase SDLC Hardening Checklist](enforce/implementation-roadmap/hardening-checklist/index.md)** - Complete implementation roadmap

    - ✅ **[Phase 1: Foundation](enforce/implementation-roadmap/hardening-checklist/phase-1/index.md)** - Pre-commit hooks, branch protection
    - ✅ **[Phase 2: Automation](enforce/implementation-roadmap/hardening-checklist/phase-2/index.md)** - CI gates, SBOM, vulnerability scanning, evidence collection
    - ✅ **[Phase 3: Runtime](enforce/implementation-roadmap/hardening-checklist/phase-3/index.md)** - Kyverno policies, pod security standards, advanced policies
    - ✅ **[Phase 4: Advanced](enforce/implementation-roadmap/hardening-checklist/phase-4/index.md)** - Audit evidence, compliance frameworks, simulation

    **[Policy Template Library](enforce/policy-as-code/template-library/index.md)** - Production-ready templates

    - ✅ **[Kyverno Templates](enforce/policy-as-code/template-library/kyverno/index.md)** - Pod security, image validation, resource limits, mandatory labels
    - ✅ **[OPA Templates](enforce/policy-as-code/template-library/opa/index.md)** - Admission control patterns
    - ✅ **[CI/CD Integration](enforce/policy-as-code/template-library/ci-cd-integration.md)** - GitHub Actions integration guide
    - ✅ **[Usage Guide](enforce/policy-as-code/template-library/usage-guide.md)** - Implementation and customization guide

    **Incident Readiness** - Playbook foundation

    - ✅ **[Playbook Library](enforce/incident-readiness/playbook-library/index.md)** - Decision trees, severity levels, response patterns

    ### Secure Section

    **Cloud Native Security** - GKE hardening and Workload Identity

    - ✅ **[GKE Hardening](secure/cloud-native/gke-hardening/index.md)** (17 guides)
        - [Cluster Configuration](secure/cloud-native/gke-hardening/cluster-configuration/index.md): Private clusters, Workload Identity, Binary Authorization
        - [IAM Configuration](secure/cloud-native/gke-hardening/iam-configuration/index.md): Least-privilege roles, federation, audit logging
        - [Network Security](secure/cloud-native/gke-hardening/network-security/index.md): VPC-native, network policies, Private Service Connect, Cloud Armor
        - [Runtime Security](secure/cloud-native/gke-hardening/runtime-security/index.md): Pod Security Standards, admission controllers, monitoring
    - ✅ **[Workload Identity](secure/cloud-native/workload-identity/index.md)** (6 guides) - Setup, migration, troubleshooting

    **Security Culture Transformation**

    - ✅ **[Tactical Playbook](secure/culture/tactical-playbook/index.md)** (9 guides)
        - Shift Left: [Pre-commit & IDE](secure/culture/tactical-playbook/pre-commit-ide.md), [Automated reviews](secure/culture/tactical-playbook/automated-reviews.md)
        - Make Visible: [Scorecards & Dashboards](secure/culture/tactical-playbook/scorecards-dashboards.md), [Notifications & Badges](secure/culture/tactical-playbook/notifications-badges.md)
        - Reduce Toil: [Automation tools](secure/culture/tactical-playbook/automation-tools.md)
        - Build Champions: [Champions Program](secure/culture/tactical-playbook/champions-program.md), [Recognition & Rewards](secure/culture/tactical-playbook/recognition-rewards.md), [Career Growth](secure/culture/tactical-playbook/career-growth.md)

    **Risk Management for Engineers**

    - ✅ **[Engineer Framework](secure/risk-management/engineer-framework/index.md)** (8 guides) - Risk assessment, CVSS interpretation, exploitability analysis, blast radius, decision trees, real-world scenarios

    ### Patterns Section

    **Reliability Patterns**

    - ✅ **[Chaos Engineering](patterns/reliability/chaos-engineering/index.md)** (12 guides)
        - [Tools comparison](patterns/reliability/chaos-engineering/tools-comparison.md), [blast radius control](patterns/reliability/chaos-engineering/blast-radius.md), [validation patterns](patterns/reliability/chaos-engineering/validation.md)
        - [Experiment design](patterns/reliability/chaos-engineering/experiment-design/index.md): [hypothesis](patterns/reliability/chaos-engineering/experiment-design/hypothesis.md), [success criteria](patterns/reliability/chaos-engineering/experiment-design/success-criteria.md), [SLI monitoring](patterns/reliability/chaos-engineering/experiment-design/sli-monitoring.md)
        - [Pod](patterns/reliability/chaos-engineering/pod-experiments.md), [network](patterns/reliability/chaos-engineering/network-experiments.md), [resource](patterns/reliability/chaos-engineering/resource-experiments.md), [dependency experiments](patterns/reliability/chaos-engineering/dependency-experiments.md)
        - [Operations](patterns/reliability/chaos-engineering/operations.md) and [observability](patterns/reliability/chaos-engineering/observability.md)

    **Security Patterns**

    - ✅ **[Secure-by-Design](patterns/security/secure-by-design/index.md)** (6 guides)
        - [Zero trust](patterns/security/secure-by-design/zero-trust.md), [defense in depth](patterns/security/secure-by-design/defense-in-depth.md), [least privilege](patterns/security/secure-by-design/least-privilege.md), [fail secure](patterns/security/secure-by-design/fail-secure.md)
        - [End-to-end integration](patterns/security/secure-by-design/integration.md) example with security audit checklist

    **Architecture Patterns**

    - ✅ **[Strangler Fig Pattern](patterns/architecture/strangler-fig/index.md)** - [Platform component replacement](patterns/architecture/strangler-fig/platform-component-replacement.md), [compatibility layers](patterns/architecture/strangler-fig/compatibility-layers.md), [validation/rollback](patterns/architecture/strangler-fig/validation-rollback.md)

    **Error Handling**

    - ✅ **[Prerequisite Checks](patterns/error-handling/prerequisite-checks/index.md)** - [Ordering patterns](patterns/error-handling/prerequisite-checks/ordering.md), [implementation](patterns/error-handling/prerequisite-checks/implementation.md), [anti-patterns](patterns/error-handling/prerequisite-checks/anti-patterns.md)

    ### Tactical Blog Posts

    **Real-World Implementation Stories** (5 new posts)

    - ✅ **[The Checklist That Passed the Audit](blog/posts/2025-12-30-checklist-passed-audit.md)** - SDLC hardening journey
    - ✅ **[The Policy That Wrote Itself](blog/posts/2025-12-31-policy-wrote-itself.md)** - Policy-as-code evolution
    - ✅ **[The 3AM Incident That Followed the Playbook](blog/posts/2026-01-01-3am-incident-followed-playbook.md)** - Incident response validation
    - ✅ **[The GKE Cluster Nobody Could Break](blog/posts/2026-01-02-gke-cluster-nobody-could-break.md)** - GKE hardening results
    - ✅ **[The CVE That Didn't Matter](blog/posts/2026-01-03-cve-that-didnt-matter.md)** - Risk-informed decision making

---

## In Progress

!!! info "Skills Marketplace Documentation"

    - ✅ **[Documentation as Skills](build/documentation-as-skills/index.md)** - Extraction pipeline, skill anatomy, marketplace versioning, CI automation
    - 🔄 Installation and team distribution guide
    - 🔄 Usage telemetry: which skills actually load

!!! info "Community Hub"

    A dedicated space to connect with security practitioners:

    - Newsletter for tactical updates
    - Discord for real-time discussion
    - Contribution guidelines for the community

---

## Planned

!!! abstract "Content Enhancements"

    **Work Avoidance Deep Dive** (#55)

    - Matrix filtering patterns
    - Deduplication strategies
    - Cache-based skip patterns
    - Performance optimization techniques

    **Social Media Automation** (#31)

    - LinkedIn cross-posting workflow
    - Medium distribution integration
    - Automated content syndication

!!! abstract "Visual Content"

    **Intro Video/Trailer** (#5)

    A short trailer explaining who we are and why enforcement matters.

!!! abstract "Homepage Improvements"

    **Call-to-Action Blocks** (#1)

    - Newsletter signup
    - Discord invite
    - GitHub stars
    - RSS feed subscription

!!! abstract "Community Features"

    **Connect Page** (#3)

    - Community channels (Discord, GitHub Discussions)
    - Newsletter signup
    - Contribution guidelines
    - Contact information

!!! abstract "Infrastructure"

    **Dependency Dashboard** (#12)

    - Automated dependency updates
    - Vulnerability scanning
    - Update tracking

---

## Get Involved

!!! tip "Want to contribute or suggest content?"

    - [GitHub](https://github.com/adaptive-enforcement-lab) - Open issues, PRs welcome
    - Watch this space for community channels
