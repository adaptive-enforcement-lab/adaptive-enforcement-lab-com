---
title: Audit Evidence Collection
description: >-
  Automated evidence capture for SDLC audits: branch protection configs, workflow logs, SBOM archives, security scans, and deployment attestations with retention strategies.
tags:
  - audit
  - compliance
  - evidence
  - sdlc
  - governance
  - operators
---

# Audit Evidence Collection

Automated evidence capture, retention strategies, and compliance reporting for SDLC audits. What to collect, how to store it, and how to retrieve it when auditors come calling.

!!! tip "Automation is Key"
    Manual evidence collection doesn't scale. Automate capture in CI/CD workflows. Store evidence in immutable S3 buckets. Retrieve with cryptographic verification. Auditors ask questions. You provide signed, tamper-proof answers.

---

## Overview

Evidence collection for compliance audits requires:

1. **Evidence Types**: What to collect (branch protection, workflow logs, SBOMs, security scans, approvals, deployments)
2. **Collection Strategies**: How to capture it (real-time vs batch, automated CI/CD)
3. **Compliance Reporting**: How to retrieve and present it to auditors
4. **Implementation**: Complete workflow examples and S3 configuration

---

## Evidence Types

The [Evidence Types guide](evidence-types.md) covers six categories:

- **Branch Protection Configurations** - Repository security settings
- **Workflow Run Logs and Artifacts** - CI/CD execution records
- **SBOM Archives** - Software Bill of Materials for supply chain transparency
- **Security Scan Results** - Trivy, Scorecard, CodeQL, Snyk outputs
- **Approval Records** - Pull request reviews and CODEOWNERS approvals
- **Deployment Attestations** - SLSA provenance and production deployment records

Each type includes:

- What to collect and why it matters
- How to capture it in GitHub Actions
- Retention policies and storage classes
- Compliance framework requirements

[View Evidence Types →](evidence-types.md)

---

## Collection Strategies

The [Collection Strategies guide](collection-strategies.md) covers:

- **Automated Capture in CI/CD** - Evidence generation in workflows
- **Retention Policies** - S3 lifecycle management and storage classes
- **Evidence Aggregation** - Bundling evidence for releases
- **Real-Time vs Batch** - When to use each approach

[View Collection Strategies →](collection-strategies.md)

---

## Compliance Reporting

The [Compliance Reporting guide](compliance-reporting.md) covers:

- **Evidence Retrieval** - Querying by date range, artifact type, or version
- **Compliance Dashboards** - Grafana and custom dashboards
- **Audit Trail Reconstruction** - Proving release compliance with evidence chains
- **Tamper-Proof Storage** - S3 Object Lock and cryptographic verification

[View Compliance Reporting →](compliance-reporting.md)

---

## Implementation

The [Implementation guide](implementation.md) provides:

- **Complete Evidence Collection Workflow** - Production-ready GitHub Actions workflow
- **S3 Bucket Setup** - Versioning, object lock, lifecycle policies
- **Evidence Lifecycle Management** - Automated transitions and cleanup

[View Implementation →](implementation.md)

---

## Related Patterns

- Blog: [Harden Your SDLC Before the Audit Comes](../../blog/posts/2025-12-12-harden-sdlc-before-audit.md) - Initial patterns and audit context
- [SLSA Provenance Implementation](../slsa-provenance/slsa-provenance.md) - Build attestations for audit trail
- [SBOM Generation](../../secure/sbom/sbom-generation.md) - Dependency evidence
- [Branch Protection](../branch-protection/branch-protection.md) - Access control evidence

---

*Evidence collection is enforcement archaeology. Every workflow run, every scan, every approval is a data point. Capture it. Store it. Prove it. Auditors come with questions. You come with cryptographically signed answers.*
