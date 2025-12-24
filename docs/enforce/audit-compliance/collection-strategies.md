---
title: Evidence Collection Strategies
description: >-
  Automated evidence capture in CI/CD workflows, retention policies, evidence aggregation, and real-time vs batch collection patterns for audit compliance.
tags:
  - audit
  - compliance
  - evidence
  - ci-cd
  - operators
---

# Evidence Collection Strategies

Automated evidence capture in CI/CD workflows, retention policies, and aggregation patterns. How to collect evidence at scale without manual intervention.

!!! tip "Automation First"
    Real-time evidence capture in CI/CD workflows eliminates data loss risk. S3 lifecycle policies manage retention automatically. Evidence aggregation creates release bundles for auditors.

---

## Automated Capture in CI/CD

**Pattern**: Every workflow generates evidence as artifacts.

```yaml
name: Evidence Collection Workflow

on:
  push:
    branches: [main]
  pull_request:

jobs:
  collect-evidence:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
    steps:
      - uses: actions/checkout@v4

      - name: Collect Evidence Bundle
        run: |
          mkdir evidence

          # Branch protection
          gh api repos/${{ github.repository }}/branches/main/protection \
            > evidence/branch-protection.json

          # Workflow metadata
          gh run view ${{ github.run_id }} --json \
            databaseId,event,headBranch,headSha,status,conclusion,createdAt \
            > evidence/workflow-metadata.json

          # Commit signature verification
          git verify-commit ${{ github.sha }} > evidence/commit-signature.txt || true

      - uses: actions/upload-artifact@v4
        with:
          name: audit-evidence-${{ github.run_id }}
          path: evidence/
          retention-days: 365
```

---

## Retention Policies

| Evidence Type | Retention Period | Storage Class | Cost Optimization |
|---------------|------------------|---------------|-------------------|
| Workflow logs | 1 year | S3 Standard | Archive to Glacier after 90 days |
| Security scans | 1 year | S3 Standard | Archive to Glacier after 180 days |
| SBOMs | Permanent | S3 Glacier IR | Immediate retrieval for active versions |
| Approvals | 3 years | S3 Standard | Archive to Deep Archive after 1 year |
| Deployments | Permanent | S3 Standard | Current deployments only |
| Branch protection | 1 year | S3 Standard | - |

**S3 Lifecycle Policy Example**:

```json
{
  "Rules": [
    {
      "Id": "Archive workflow logs after 90 days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "workflow-logs/"
      },
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    },
    {
      "Id": "Archive security scans after 180 days",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "scans/"
      },
      "Transitions": [
        {
          "Days": 180,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
```

---

## Evidence Aggregation

**Pattern**: Bundle all evidence for a release into a single archive.

```yaml
- name: Create Release Evidence Bundle
  run: |
    VERSION="${{ github.ref_name }}"
    mkdir -p evidence-bundle

    # Collect all evidence for this release
    aws s3 cp s3://audit-evidence/sboms/${VERSION}/ evidence-bundle/sbom/ --recursive
    aws s3 cp s3://audit-evidence/scans/${VERSION}/ evidence-bundle/scans/ --recursive
    cp multiple.intoto.jsonl evidence-bundle/slsa-provenance.jsonl

    # Create signed archive
    tar -czf evidence-${VERSION}.tar.gz evidence-bundle/
    cosign sign-blob --bundle evidence-${VERSION}.tar.gz.sig evidence-${VERSION}.tar.gz

    # Upload bundle
    aws s3 cp evidence-${VERSION}.tar.gz s3://audit-evidence/bundles/
    aws s3 cp evidence-${VERSION}.tar.gz.sig s3://audit-evidence/bundles/
```

---

## Real-Time vs Batch Collection

**Real-Time** (Preferred):

- Evidence captured during workflow execution
- Lower risk of data loss
- Immediate availability
- Example: Workflow logs uploaded to S3 at end of each run

**Batch** (Fallback):

- Periodic aggregation from multiple sources
- Useful for GitHub API data (PRs, reviews)
- Risk: Data may be deleted before collection
- Example: Weekly cron job to export all merged PRs

**Recommendation**: Use real-time for critical evidence (SLSA provenance, security scans). Batch is acceptable for historical aggregation (PR statistics, contribution metrics).

---

## Related Patterns

- [Audit Evidence Collection](audit-evidence.md) - Main overview
- [Evidence Types](evidence-types.md) - What to collect
- [Compliance Reporting](compliance-reporting.md) - How to retrieve evidence
- [Implementation](implementation.md) - Complete workflow examples

---

*Real-time capture eliminates data loss. Lifecycle policies manage retention automatically. Evidence aggregation creates audit-ready bundles. Automate collection. Enforce retention. Prove compliance.*
