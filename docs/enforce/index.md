---
title: Enforce
tags:
  - policy-enforcement
  - security
  - compliance
  - automation
  - operators
  - security-teams
description: >-
  Make security mandatory through automation. Branch protection, pre-commit hooks, status checks, policy-as-code, and SLSA provenance for SOC 2 compliance.
---
# Enforce

Making security mandatory through automation.

!!! warning "Enforcement Over Education"

    **If you can't enforce it, it doesn't matter.** Documentation, training, and recommendations don't scale. Security controls that can be bypassed eventually will be bypassed.

## Overview

This section covers the **enforcement mechanisms** that make security policies mandatory, auditable, and impossible to ignore.

These controls pass SOC 2, ISO 27001, and PCI-DSS audits by shifting security left and making compliance automatic.

## Secure vs Enforce

Understanding the distinction:

- **Secure** ([see Secure](../secure/index.md)): Find and fix security issues
  - Vulnerability scanners that *identify* CVEs
  - SBOM generators that *document* dependencies
  - Security tools that *discover* weaknesses

- **Enforce** (this section): Make security mandatory through automation
  - Branch protection that *requires* reviews
  - Pre-commit hooks that *block* violations
  - Status checks that *prevent* merges
  - Policy-as-code that *rejects* non-compliant resources
  - SLSA provenance that *attests* build integrity

**Litmus test**: Can a developer bypass this control?

- If **yes** → It belongs in **Secure** (it finds issues, but doesn't mandate fixes).
- If **no** → It belongs in **Enforce** (it makes security mandatory).

## What You'll Find Here

### Branch Protection

Require code reviews, status checks, and commit signatures on protected branches to prevent direct commits and ensure peer review.

### Pre-commit Hooks

Catch violations at commit time, before CI/CD runs, by blocking commits that violate security policies, code standards, or compliance.

### Status Checks

Use GitHub status checks to gate pull request merges, requiring tests, security scans, and other validations to pass before allowing merges.

### Policy-as-Code

Prevent misconfigured resources from being deployed to Kubernetes with admission controllers like Kyverno and OPA.

### SLSA Provenance

Generate signed attestations to prove build integrity and mitigate supply chain risks.

### Testing Enforcement

Enforce minimum code coverage and require tests for new code to prevent untested code from reaching production.

### Audit & Compliance

Automate audit evidence collection for SOC 2, ISO 27001, and PCI-DSS to streamline compliance.

## Common Workflows

### 1. Enforce Branch Protection

```bash
# Require 2 reviews, passing tests, and commit signatures
gh api repos/org/repo/branches/main/protection \
  --method PUT \
  --field required_pull_request_reviews[required_approving_review_count]=2 \
  --field required_status_checks[strict]=true \
  --field required_status_checks[contexts][]=test \
  --field required_status_checks[contexts][]=security-scan \
  --field required_signatures[enabled]=true
```

### 2. Pre-commit Hook for Secret Detection

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/trufflesecurity/trufflehog
    rev: v3.63.0
    hooks:
      - id: trufflehog
        name: TruffleHog
        entry: bash -c 'trufflehog git file://. --since-commit HEAD --only-verified --fail'
```

### 3. Kyverno Policy Enforcement

```yaml
# Enforce resource limits on all pods
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-resource-limits
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Resource limits are required"
        pattern:
          spec:
            containers:
              - resources:
                  limits:
                    memory: "?*"
                    cpu: "?*"
```

### 4. SLSA Provenance Generation

```yaml
# .github/workflows/release.yml
permissions:
  id-token: write  # Required for SLSA provenance
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build artifact
        run: make build
      - name: Generate SLSA provenance
        uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v1.9.0
        with:
          artifacts: dist/*
```

## Enforcement Hierarchy

Enforcement controls work in layers:

1. **Pre-commit hooks** (fastest feedback)
   - Catch violations before commit
   - Developer workstation enforcement
   - Can be bypassed with `--no-verify` (use server-side for critical policies)

2. **Status checks** (PR merge gates)
   - Automated quality gates
   - Enforce in CI/CD pipeline
   - Cannot be bypassed without admin override

3. **Branch protection** (repository controls)
   - Prevent direct commits
   - Require reviews and status checks
   - Restrict who can merge

4. **Policy-as-code** (runtime enforcement)
   - Admission control at API server
   - Cannot be bypassed by developers
   - Mutate or reject non-compliant resources

**Best practice**: Layer multiple enforcement mechanisms. Pre-commit hooks for fast feedback, status checks for automation, policy-as-code for runtime protection.

## Integration with Secure

Enforcement is only effective when paired with security tooling:

1. **Find vulnerabilities** ([Secure](../secure/index.md)) → **Block deployment** (Enforce)
2. **Generate SBOM** ([Secure](../secure/index.md)) → **Require SBOM in PR** (Enforce)
3. **Run Scorecard** ([Secure](../secure/index.md)) → **Enforce minimum score** (Enforce)
4. **Scan containers** ([Secure](../secure/index.md)) → **Block vulnerable images** (Enforce)

## Implementation Roadmap

See [Implementation Roadmap](implementation-roadmap/index.md) for phased rollout:

1. **Phase 1**: Branch protection (1 week)
2. **Phase 2**: Status checks (2 weeks)
3. **Phase 3**: Pre-commit hooks (1 week)
4. **Phase 4**: Policy-as-code (4 weeks)
5. **Phase 5**: SLSA provenance (2 weeks)

**Total timeline**: 10 weeks for complete enforcement stack.

## Getting Started

1. **Start with branch protection**: Require reviews and passing tests
2. **Add status checks**: Block PRs that fail security scans
3. **Deploy pre-commit hooks**: Catch secrets before they're committed
4. **Layer on policy-as-code**: Enforce runtime compliance
5. **Add SLSA provenance**: Prove build integrity

## Common Challenges

### "Enforcement slows down developers"

**Reality**: Finding and fixing issues in production is 10x slower than catching them in CI.

**Solution**: Layer enforcement to provide fast feedback (pre-commit hooks) before slow feedback (CI/CD).

### "Developers will just bypass the controls"

**Reality**: Some controls (like pre-commit hooks) can be bypassed. Others (like policy-as-code) cannot.

**Solution**: Use client-side enforcement for fast feedback, server-side enforcement for critical policies.

### "We need exceptions for emergencies"

**Reality**: Every organization needs break-glass procedures.

**Solution**: Document exception processes. Use temporary admin overrides with audit trails, not permanent bypasses.

## Related Content

- [Secure](../secure/index.md): Find and fix security issues
- [Build](../build/index.md): CI/CD pipelines and release automation
- [Patterns](../patterns/index.md): Reusable enforcement patterns

## Tags

Browse all content tagged with policy-enforcement, automation, compliance, and security on the [Tags](../tags.md) page.
