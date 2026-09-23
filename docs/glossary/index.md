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

SLSA is a security framework. It has four levels for ensuring supply chain integrity. It proves build integrity using cryptographic attestations. This helps prevent tampering.

**Related**: [SLSA Provenance](../enforce/slsa-provenance/slsa-provenance.md) | [SLSA Levels](../enforce/slsa-provenance/slsa-levels.md) | [SLSA vs SBOM](../enforce/slsa-provenance/slsa-vs-sbom.md)

### Provenance

Provenance is cryptographic proof. It shows how a software artifact was built. It records the source commit and build details. Digital signatures prevent tampering. Provenance is required for SLSA Level 2 and higher.

**Related**: [SLSA Provenance](../enforce/slsa-provenance/slsa-provenance.md) | [Verification Workflows](../enforce/slsa-provenance/verification-workflows.md)

### Attestation

An attestation is a signed statement about software artifacts. It uses cryptographic signatures. This makes verifiable claims about builds, tests, or scans.

**Related**: [SLSA Provenance](../enforce/slsa-provenance/slsa-provenance.md) | [Policy Templates](../enforce/slsa-provenance/policy-templates.md)

### SBOM (Software Bill of Materials)

An SBOM is a complete list of all software components. This includes all libraries and dependencies. It helps with vulnerability tracking and license compliance.

**Related**: [SBOM Generation](../secure/sbom/sbom-generation.md) | [SLSA vs SBOM](../enforce/slsa-provenance/slsa-vs-sbom.md)

### Sigstore

Sigstore is an open-source project for signing software.

It provides free code signing. It uses short-lived certificates and maintains transparency logs. No key management is needed. OpenSSF and GitHub Actions use Sigstore.

**Related**: [SLSA Provenance](../enforce/slsa-provenance/slsa-provenance.md) | [Container Release](../secure/github-actions-security/examples/release-workflow/container-release.md)

### Cosign

Cosign is a tool for signing container images.

It is part of Sigstore. Cosign signs container images. It stores these signatures in OCI registries. It also integrates with admission controllers.

**Related**: [Image Signing](../enforce/policy-as-code/template-library/kyverno/image/signing.md) | [Image Verification](../enforce/policy-as-code/template-library/opa/image/verification.md)

---

## Policy & Compliance

### Policy-as-Code

Policy-as-Code involves writing security and compliance policies. These policies are version-controlled, testable, and executable code. Tools like OPA, Kyverno, and Gatekeeper implement this concept.

**Related**: [Policy-as-Code Overview](../enforce/policy-as-code/index.md) | [Policy Templates](../enforce/policy-as-code/template-library/index.md)

### OPA (Open Policy Agent)

OPA is a policy engine. It uses the Rego language. OPA enforces policies across the cloud-native stack. It is often used with Gatekeeper for Kubernetes.

**Related**: [OPA Templates](../enforce/policy-as-code/template-library/opa/index.md) | [OPA vs Kyverno](../enforce/policy-as-code/template-library/opa-kyverno-comparison.md)

### Kyverno

Kyverno is a Kubernetes-native policy engine. It validates, mutates, and generates resources using YAML. This enables policy enforcement during local development, CI, and runtime.

**Related**: [Kyverno Basics](../enforce/policy-as-code/kyverno/index.md) | [Kyverno Templates](../enforce/policy-as-code/template-library/kyverno/index.md) | [CI/CD Integration](../enforce/policy-as-code/kyverno/ci-cd-integration.md)

### Gatekeeper

Gatekeeper integrates OPA with Kubernetes. It uses Rego policies. Gatekeeper validates and mutates resources through an admission controller webhook.

**Related**: [OPA Templates](../enforce/policy-as-code/template-library/opa/index.md) | [Migration Guide](../enforce/policy-as-code/template-library/opa-kyverno-migration.md)

### Admission Controllers

Admission controllers are Kubernetes components. They intercept API requests before these requests are saved. This allows for validation and mutation of resources. Kyverno and Gatekeeper are examples of admission controllers.

**Related**: [Policy-as-Code](../enforce/policy-as-code/index.md) | [Runtime Deployment](../enforce/policy-as-code/runtime-deployment/index.md)

### Scorecard

Scorecard is an OpenSSF tool. It measures security best practices. It runs 18 checks and scores each from 0 to 10. High scores show a strong security posture.

**Related**: [Scorecard Guide](../secure/scorecard/index.md) | [Score Progression](../secure/scorecard/score-progression.md) | [CI Integration](../secure/scorecard/ci-integration.md)

---

## Architecture Patterns

### Hub-and-Spoke

Hub-and-Spoke is a centralized distribution pattern. A central hub repository controls many spoke repositories. This provides centralized control for policies across an organization.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md)

### Three-Stage Design

This workflow has three phases: Discovery, Distribution, and Summary. It makes errors visible. Each phase can roll back independently.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md) | [Three-Stage Design](../patterns/architecture/three-stage-design.md)

### Strangler Fig

Strangler Fig is an incremental migration pattern. It helps replace old systems. Both old and new systems run in parallel. Traffic gradually shifts to the new system with no downtime.

**Related**: [Strangler Fig Overview](../patterns/architecture/strangler-fig/index.md) | [Traffic Routing](../patterns/architecture/strangler-fig/traffic-routing.md) | [Migration Guide](../patterns/architecture/strangler-fig/migration-guide.md)

### Separation of Concerns

This design principle states that components should have a single responsibility. They should also have clear boundaries. This separates orchestration from business logic. It improves maintainability.

**Related**: [Separation of Concerns](../patterns/architecture/separation-of-concerns/index.md) | [Implementation](../patterns/architecture/separation-of-concerns/implementation.md) | [Go CLI Architecture](../build/go-cli-architecture/index.md)

### Matrix Distribution

Matrix distribution is a CI/CD pattern. It runs operations in parallel. It uses a dynamic set of targets. This enables parallel processing and conditional execution.

**Related**: [Matrix Distribution](../patterns/architecture/matrix-distribution/index.md) | [Conditional Distribution](../patterns/architecture/matrix-distribution/conditional-distribution.md)

### Environment Progression

Environment progression is a deployment strategy. It moves code through a series of environments (like dev, staging, prod). This validates changes and automates rollbacks.

**Related**: [Environment Progression](../patterns/architecture/environment-progression.md) | [Operations](../patterns/architecture/environment-progression-operations.md) | [Testing Blog](../blog/posts/2025-12-16-environment-progression-testing.md)

---

## Efficiency Patterns

### Idempotency

Idempotency is an operation. It can be run multiple times. The result does not change after the initial application. This makes retries safe and automation reliable.

**Related**: [Idempotency Overview](../patterns/efficiency/idempotency/index.md) | [Idempotent Automation](../blog/posts/2025-11-27-idempotent-automation.md) | [Decision Matrix](../patterns/efficiency/idempotency/decision-matrix.md)

### Work Avoidance

Work avoidance uses patterns to skip unnecessary work. It uses techniques like change detection and caching. This reduces runtime and cost.

**Related**: [Work Avoidance Overview](../patterns/efficiency/work-avoidance/index.md) | [5 Seconds to 5 Milliseconds](../blog/posts/2025-11-29-from-5-seconds-to-5-milliseconds.md) | [Techniques](../patterns/efficiency/work-avoidance/techniques/index.md)

### Check-Before-Act

This is the most common idempotency pattern. It checks if a resource exists before creating it. This avoids errors and redundant work. However, it is subject to race conditions.

**Related**: [Check-Before-Act Pattern](../patterns/efficiency/idempotency/patterns/check-before-act.md) | [Idempotency Patterns](../patterns/efficiency/idempotency/patterns/index.md)

### Tombstone Markers

Tombstone markers are a work-avoidance technique. They leave a marker (like a file) after a task is done. This allows later runs to skip the operation.

**Related**: [Tombstone Markers](../patterns/efficiency/idempotency/patterns/tombstone-markers.md)

### Content Hashing

Content hashing is a change-detection technique. It uses cryptographic hashes. This determines if content has changed. It helps avoid unnecessary processing.

**Related**: [Content Hashing](../patterns/efficiency/work-avoidance/techniques/content-hashing.md) | [Cache-Based Skip](../patterns/efficiency/work-avoidance/techniques/cache-based-skip.md)

### Caching

Caching means storing the results of expensive operations. These results can be reused later. Effective cache invalidation is critical for this pattern.

**Related**: [Cache Considerations](../patterns/efficiency/idempotency/caches.md) | [Cache-Based Skip](../patterns/efficiency/work-avoidance/techniques/cache-based-skip.md)

---

## CI/CD & Automation

### GitHub Actions

GitHub Actions is GitHub's CI/CD platform. It automates workflows. Workflows are triggered by events. Jobs run in parallel, and steps execute commands.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md) | [File Distribution](../patterns/github-actions/use-cases/file-distribution/index.md) | [Work Avoidance](../patterns/github-actions/use-cases/work-avoidance/index.md)

### GitHub Apps

GitHub Apps are applications at the organization level. They provide a secure and auditable machine identity. They also have higher rate limits. This is critical for operations across multiple repositories.

**Related**: [GitHub Core App](../secure/github-apps/index.md) | [Token Generation](../patterns/github-actions/actions-integration/token-generation/index.md) | [Token Lifecycle](../patterns/github-actions/actions-integration/token-lifecycle/index.md)

### Argo Workflows

Argo Workflows is a Kubernetes-native workflow engine. It uses YAML to define complex, container-based workflows. It supports retries, error handling, and templates.

**Related**: [Argo Workflows Patterns](../patterns/argo-workflows/index.md) | [WorkflowTemplate Patterns](../patterns/argo-workflows/templates/index.md) | [Workflow Composition](../patterns/argo-workflows/composition/index.md)

### Argo Events

Argo Events is an event-driven workflow automation framework for Kubernetes. It connects different systems. It uses event sources and sensors to trigger reactive workflows.

**Related**: [Argo Events Overview](../patterns/argo-events/index.md) | [Event Routing](../patterns/argo-events/routing/index.md) | [Reliability Patterns](../patterns/argo-events/reliability/index.md)

### Release-Please

Release-Please is an automated versioning tool. It generates changelogs and creates release pull requests. It also tags releases based on Conventional Commit messages.

**Related**: [Release-Please Configuration](../build/release-pipelines/release-please/index.md) | [Workflow Integration](../build/release-pipelines/release-please/workflow-integration.md)

### Pre-commit Hooks

Pre-commit hooks are Git hooks. They run before a commit is created. They provide fast feedback by blocking secrets and other violations. This prevents them from entering the codebase.

**Related**: [Pre-commit Hooks](../enforce/pre-commit-hooks/pre-commit-hooks.md) | [Pre-commit Patterns](../enforce/pre-commit-hooks/pre-commit-hooks-patterns.md)

### Reusable Workflows

Reusable workflows are parameterized GitHub Actions workflows. Other workflows can call them. This centralizes logic and allows reuse across many repositories.

**Related**: [GitHub Actions Integration](../patterns/github-actions/actions-integration/index.md) | [File Distribution](../patterns/github-actions/use-cases/file-distribution/index.md)

### Conventional Commits

Conventional Commits use a structured message format (e.g., 'type(scope): description'). This format enables automation for changelog generation and version bumps.

**Related**: [Release-Please Configuration](../build/release-pipelines/release-please/index.md) | [Versioned Docs](../build/versioned-docs/index.md)

### WorkflowTemplate

A WorkflowTemplate is a reusable Argo Workflow definition. It can be parameterized. Other workflows can reference it. This helps compose complex pipelines in Kubernetes.

**Related**: [WorkflowTemplate Patterns](../patterns/argo-workflows/templates/index.md) | [Workflow Composition](../patterns/argo-workflows/composition/index.md)

---

## Security & Hardening

### Zero Trust

Zero Trust means no implicit trust.

Every request needs verification. Network location does not matter. Verification happens at every layer.

**Related**: [Secure-by-Design](../patterns/security/secure-by-design/zero-trust.md)

### Defense in Depth

Defense in Depth uses multiple security layers.

Each layer adds protection. The layers work independently. A single breach cannot destroy everything.

**Related**: [Defense in Depth](../patterns/security/secure-by-design/defense-in-depth.md)

### Least Privilege

Least Privilege means giving only the minimum permissions needed.

This limits damage from breaches. It is required for good security.

**Related**: [Least Privilege](../patterns/security/secure-by-design/least-privilege.md)

### Fail Secure

Fail Secure means failures default to safe states.

When controls fail, access is denied. This prevents bypass. Kubernetes uses 'failurePolicy: Fail'.

**Related**: [Fail Secure](../patterns/security/secure-by-design/fail-secure.md) | [Integration](../patterns/security/secure-by-design/integration.md)

### Branch Protection

Branch protection consists of GitHub rules. These rules enforce security on branches.

It requires code review and blocks force pushes. It also requires status checks. Drift is common, but automated enforcement fixes it.

**Related**: [Branch Protection](../enforce/branch-protection/index.md) | [Security Tiers](../enforce/branch-protection/security-tiers.md) | [Drift Detection](../enforce/branch-protection/drift-detection.md)

### Commit Signing

Commit signing provides cryptographic proof of authorship.

Git author fields are easy to forge. GPG signatures prove who made a commit. This is required for audits.

**Related**: [Commit Signing](../enforce/commit-signing/commit-signing.md) | [Implementation Roadmap](../enforce/implementation-roadmap/index.md)

### Workload Identity

Workload Identity enables cloud authentication without static keys.

Containers use JWT tokens instead of static keys. These tokens rotate automatically. This removes a large attack surface.

**Related**: [Workload Identity](../secure/cloud-native/workload-identity/index.md) | [Migration Guide](../secure/cloud-native/workload-identity/migration-guide.md)

### GKE Hardening

GKE Hardening improves security for Google Kubernetes Engine.

It includes private clusters, Workload Identity, Binary Authorization, and Infrastructure as Code.

**Related**: [GKE Hardening](../secure/cloud-native/gke-hardening/index.md) | [Cluster Configuration](../secure/cloud-native/gke-hardening/cluster-configuration/index.md) | [Network Security](../secure/cloud-native/gke-hardening/network-security/index.md)

---

!!! tip "Missing a Term?"

    If you find terminology not defined here, please [open an issue](https://github.com/adaptive-enforcement-lab/adaptive-enforcement-lab-com/issues).

**Related**: [Roadmap](../roadmap.md) | [Patterns](../patterns/index.md) | [Blog](../blog/index.md)
