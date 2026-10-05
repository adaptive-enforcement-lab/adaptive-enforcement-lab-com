---
title: DevSecOps Glossary
description: >-
  Comprehensive glossary of DevSecOps terminology, policy-as-code concepts,
  and security automation patterns used throughout Adaptive Enforcement Lab.
---

# DevSecOps Glossary

!!! abstract "Quick Reference"

    Specialized terminology for security teams and DevSecOps practitioners. Each term includes practical context and links to relevant documentation.

---

## Supply Chain Security

### SLSA (Supply chain Levels for Software Artifacts)

A security framework with four levels for supply chain integrity.

SLSA proves build integrity using cryptographic attestation. It identifies the source and build process. It verifies build isolation. SLSA prevents supply chain attacks like SolarWinds.

**Related**: [SLSA Playbook](../enforce/slsa-provenance/index.md) | [SLSA Levels](../enforce/slsa-provenance/slsa-levels.md) | [SLSA vs SBOM](../enforce/slsa-provenance/slsa-vs-sbom.md)

### Provenance

Cryptographic proof of how an artifact was built.

Provenance records the source commit and build details. Digital signatures prevent tampering. This verifies artifacts match their source. Required for SLSA Level 2+.

**Related**: [SLSA Provenance](../enforce/slsa-provenance/slsa-provenance.md) | [Verification Workflows](../enforce/slsa-provenance/verification-workflows.md)

### Attestation

A signed statement about software artifacts.

Attestations make verifiable claims using cryptographic signatures. They cover builds, tests, or scans. Multiple attestations can be combined.

**Related**: [SLSA Provenance](../enforce/slsa-provenance/slsa-provenance.md) | [Policy Templates](../enforce/slsa-provenance/policy-templates.md)

### SBOM (Software Bill of Materials)

A complete list of all software components. It includes all libraries and dependencies. Enables vulnerability tracking. Enables license compliance. Different from SLSA provenance.

**Related**: [SBOM Generation](../secure/sbom/sbom-generation.md) | [SLSA vs SBOM](../enforce/slsa-provenance/slsa-vs-sbom.md)

### Sigstore

An open-source project for signing software.

Sigstore provides free code signing. It uses short-lived certificates. It maintains transparency logs. No key management needed. Used by OpenSSF and GitHub Actions.

**Related**: [SLSA Provenance](../enforce/slsa-provenance/slsa-provenance.md) | [Container Release](../secure/github-actions-security/examples/release-workflow/container-release.md)

### Cosign

A tool for signing container images.

Cosign is part of Sigstore. It signs images. It stores signatures in OCI registries. It integrates with admission controllers.

**Related**: [Image Signing](../enforce/policy-as-code/template-library/kyverno/image/signing.md) | [Image Verification](../enforce/policy-as-code/template-library/opa/image/verification.md)

---

## Policy & Compliance

### Policy-as-Code

Security and compliance policies expressed as executable code.

Policies can be version controlled and tested. They are automatically enforced. Code policies block violations. Implemented using OPA, Kyverno, and Gatekeeper.

**Related**: [Policy-as-Code Overview](../enforce/policy-as-code/index.md) | [Policy Templates](../enforce/policy-as-code/template-library/index.md)

### OPA (Open Policy Agent)

A policy engine that uses Rego language for rules.

OPA evaluates policies across cloud-native stacks. It works with Kubernetes through Gatekeeper. Policies are decoupled from code. Used for authorization and compliance.

**Related**: [OPA Templates](../enforce/policy-as-code/template-library/opa/index.md) | [OPA vs Kyverno](../enforce/policy-as-code/template-library/opa-kyverno-comparison.md)

### Kyverno

A Kubernetes-native policy engine using YAML.

Kyverno validates and mutates resources. No new language to learn. Works at local dev, CI, and runtime. Enforces policies at all three layers.

**Related**: [Kyverno Basics](../enforce/policy-as-code/kyverno/index.md) | [Kyverno Templates](../enforce/policy-as-code/template-library/kyverno/index.md) | [CI/CD Integration](../enforce/policy-as-code/kyverno/ci-cd-integration.md)

### Gatekeeper

OPA integration for Kubernetes.

Gatekeeper uses Rego policies. It deploys as a webhook. Templates define reusable policies.

**Related**: [OPA Templates](../enforce/policy-as-code/template-library/opa/index.md) | [Migration Guide](../enforce/policy-as-code/template-library/opa-kyverno-migration.md)

### Admission Controllers

Kubernetes components that intercept API requests.

They run before persistence. They validate or mutate resources. Kyverno and Gatekeeper are admission controllers. Critical for security.

**Related**: [Policy-as-Code](../enforce/policy-as-code/index.md) | [Runtime Deployment](../enforce/policy-as-code/runtime-deployment/index.md)

### Scorecard

OpenSSF tool that measures security practices.

Scorecard evaluates 18 checks. Each scores 0 to 10. Checks cover branch protection and code review. High scores are a byproduct of good security.

**Related**: [Scorecard Guide](../secure/scorecard/index.md) | [Score Progression](../secure/scorecard/score-progression.md) | [CI Integration](../secure/scorecard/ci-integration.md)

---

## Architecture Patterns

### Hub-and-Spoke

A centralized distribution pattern.

The hub controls many spoke repositories. Provides centralized control. Common for organization-wide policies.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md)

### Three-Stage Design

A workflow with three phases: Discovery, Distribution, and Summary.

Makes errors visible. Each phase has clear success criteria. Each phase can roll back.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md) | [Three-Stage Design](../patterns/architecture/three-stage-design.md)

### Strangler Fig

Incremental migration for replacing legacy systems.

Run old and new systems in parallel. Gradually shift traffic. Zero downtime. Rollback at any point.

**Related**: [Strangler Fig Overview](../patterns/architecture/strangler-fig/index.md) | [Traffic Routing](../patterns/architecture/strangler-fig/traffic-routing.md) | [Migration Guide](../patterns/architecture/strangler-fig/migration-guide.md)

### Separation of Concerns

Single-responsibility components with clear boundaries.

Every component does one thing well. Orchestration separated from business logic. Maintainability at scale.

**Related**: [Separation of Concerns](../patterns/architecture/separation-of-concerns/index.md) | [Implementation](../patterns/architecture/separation-of-concerns/implementation.md) | [Go CLI Architecture](../build/go-cli-architecture/index.md)

### Matrix Distribution

Run operations in parallel across targets.

Matrix strategies enable parallel processing. Discovery builds the target list. Distribution spawns parallel jobs.

**Related**: [Matrix Distribution](../patterns/architecture/matrix-distribution/index.md) | [Conditional Distribution](../patterns/architecture/matrix-distribution/conditional-distribution.md)

### Environment Progression

Progressive deployment across environments.

Deploy to dev, then staging, then production. Test with realistic load. Validate migrations. Automate rollback.

**Related**: [Environment Progression](../patterns/architecture/environment-progression.md) | [Operations](../patterns/architecture/environment-progression-operations.md) | [Testing Blog](../blog/posts/2025-12-16-environment-progression-testing.md)

---

## Efficiency Patterns

### Idempotency

An operation that always gives the same result.

Run it once or a thousand times. The result is identical. Makes retries safe. Critical for automation.

**Related**: [Idempotency Overview](../patterns/efficiency/idempotency/index.md) | [Idempotent Automation](../blog/posts/2025-11-27-idempotent-automation.md) | [Decision Matrix](../patterns/efficiency/idempotency/decision-matrix.md)

### Work Avoidance

Patterns for skipping unnecessary work.

These reduce runtime and costs. Complements idempotency. Uses change detection and caching.

**Related**: [Work Avoidance Overview](../patterns/efficiency/work-avoidance/index.md) | [5 Seconds to 5 Milliseconds](../blog/posts/2025-11-29-from-5-seconds-to-5-milliseconds.md) | [Techniques](../patterns/efficiency/work-avoidance/techniques/index.md)

### Check-Before-Act

Check state before creating it.

The most common pattern. Check if state exists. Skip if yes. Act if no. Watch for race conditions.

**Related**: [Check-Before-Act Pattern](../patterns/efficiency/idempotency/patterns/check-before-act.md) | [Idempotency Patterns](../patterns/efficiency/idempotency/patterns/index.md)

### Tombstone Markers

Leave markers when operations complete.

Create a marker file when done. On rerun, check for marker. Skip if present. Universal fallback.

**Related**: [Tombstone Markers](../patterns/efficiency/idempotency/patterns/tombstone-markers/index.md) | [CI/CD Examples](../patterns/efficiency/idempotency/patterns/tombstone-markers/ci-cd-examples.md)

### Content Hashing

Use hashes to detect changes.

Compute hash of content. Compare hashes. If hashes match, content is identical. Skip processing.

**Related**: [Content Hashing](../patterns/efficiency/work-avoidance/techniques/content-hashing.md) | [Cache-Based Skip](../patterns/efficiency/work-avoidance/techniques/cache-based-skip.md)

### Caching

Store results for reuse.

Save results for later use. Cache invalidation is hard. Design for cache hits. Survive cache misses.

**Related**: [Cache Considerations](../patterns/efficiency/idempotency/caches.md) | [Cache-Based Skip](../patterns/efficiency/work-avoidance/techniques/cache-based-skip.md)

---

## CI/CD & Automation

### GitHub Actions

GitHub CI/CD platform for workflows.

Workflows run on events. Jobs run in parallel. Steps execute commands.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md) | [File Distribution](../patterns/github-actions/use-cases/file-distribution/index.md) | [Work Avoidance](../patterns/github-actions/use-cases/work-avoidance/index.md)

### GitHub Apps

Organization apps for authentication.

Apps provide machine identity. All actions auditable. Higher rate limits. Critical for cross-repo operations.

**Related**: [GitHub Core App](../secure/github-apps/index.md) | [Token Generation](../patterns/github-actions/actions-integration/token-generation/index.md) | [Token Lifecycle](../patterns/github-actions/actions-integration/token-lifecycle/index.md)

### Argo Workflows

Kubernetes workflow engine.

Define workflows in YAML. Run steps in containers. Handle retries and errors. Compose from templates.

**Related**: [Argo Workflows Patterns](../patterns/argo-workflows/index.md) | [WorkflowTemplate Patterns](../patterns/argo-workflows/templates/index.md) | [Workflow Composition](../patterns/argo-workflows/composition/index.md)

### Argo Events

Event-driven workflows for Kubernetes.

Connect systems to reactive workflows. EventSources capture events. Sensors trigger actions. No polling needed.

**Related**: [Argo Events Overview](../patterns/argo-events/index.md) | [Event Routing](../patterns/argo-events/routing/index.md) | [Reliability Patterns](../patterns/argo-events/reliability/index.md)

### Release-Please

Automated versioning from commits.

Reads commit history. Generates changelogs. Creates release PRs. Tags releases. No manual version management.

**Related**: [Release-Please Configuration](../build/release-pipelines/release-please/index.md) | [Workflow Integration](../build/release-pipelines/release-please/workflow-integration.md)

### Pre-commit Hooks

Git hooks before commits.

Block bad code from history. Check for secrets and violations. Faster feedback than CI.

**Related**: [Pre-commit Hooks](../enforce/pre-commit-hooks/pre-commit-hooks.md) | [Pre-commit Patterns](../enforce/pre-commit-hooks/pre-commit-hooks-patterns.md)

### Reusable Workflows

Parameterized workflows called by others.

Define once. Call from many repos. Centralize logic. Reduce duplication.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md) | [File Distribution](../patterns/github-actions/use-cases/file-distribution/index.md)

### Conventional Commits

Structured commit messages for automation.

Format: `type(scope): description`. Enables changelog and version bumps. Required for Release-Please.

**Related**: [Release-Please Configuration](../build/release-pipelines/release-please/index.md) | [Versioned Docs](../build/versioned-docs/index.md)

### WorkflowTemplate

Reusable Argo Workflow in Kubernetes.

Define once. Reference from many workflows. Parameterize. Compose pipelines.

**Related**: [WorkflowTemplate Patterns](../patterns/argo-workflows/templates/index.md) | [Workflow Composition](../patterns/argo-workflows/composition/index.md)

---

## Security & Hardening

### Zero Trust

No implicit trust.

Every request needs verification. Network location does not matter. Verify at every layer.

**Related**: [Secure-by-Design](../patterns/security/secure-by-design/zero-trust.md)

### Defense in Depth

Multiple security layers.

Each layer adds protection. Layers work independently. One breach cannot destroy everything.

**Related**: [Defense in Depth](../patterns/security/secure-by-design/defense-in-depth.md)

### Least Privilege

Minimum permissions needed.

Give only what is needed. Limits damage from breaches. Required for security.

**Related**: [Least Privilege](../patterns/security/secure-by-design/least-privilege.md)

### Fail Secure

Failures default to safe states.

When controls fail, deny access. Prevents bypass. Kubernetes uses `failurePolicy: Fail`.

**Related**: [Fail Secure](../patterns/security/secure-by-design/fail-secure.md) | [Integration](../patterns/security/secure-by-design/integration.md)

### Branch Protection

GitHub rules enforcing security on branches.

Requires code review. Blocks force pushes. Requires status checks. Drift is common. Automated enforcement fixes drift.

**Related**: [Branch Protection](../enforce/branch-protection/index.md) | [Security Tiers](../enforce/branch-protection/security-tiers.md) | [Drift Detection](../enforce/branch-protection/drift-detection.md)

### Commit Signing

Cryptographic proof of authorship.

Git author fields are trivial to forge. GPG signatures prove authorship. Required for audits.

**Related**: [Commit Signing](../enforce/commit-signing/commit-signing.md) | [Implementation Roadmap](../enforce/implementation-roadmap/index.md)

### Workload Identity

Cloud auth without static keys.

Containers use JWT tokens instead of keys. Tokens rotate automatically. Eliminates largest attack surface.

**Related**: [Workload Identity](../secure/cloud-native/workload-identity/index.md) | [Migration Guide](../secure/cloud-native/workload-identity/migration-guide.md)

### GKE Hardening

Security for Google Kubernetes Engine.

Private clusters. Workload Identity. Binary Authorization. Infrastructure as Code.

**Related**: [GKE Hardening](../secure/cloud-native/gke-hardening/index.md) | [Cluster Configuration](../secure/cloud-native/gke-hardening/cluster-configuration/index.md) | [Network Security](../secure/cloud-native/gke-hardening/network-security/index.md)

---

!!! tip "Missing a Term?"

    If you find terminology not defined here, please [open an issue](https://github.com/adaptive-enforcement-lab/adaptive-enforcement-lab.com/issues).

**Related**: [Roadmap](../roadmap.md) | [Patterns](../patterns/index.md) | [Blog](../blog/index.md)
