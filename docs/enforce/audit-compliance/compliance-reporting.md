---
title: Compliance Reporting and Evidence Retrieval
description: >-
  Evidence retrieval for audits, compliance dashboards, audit trail reconstruction, and tamper-proof storage with S3 Object Lock and cryptographic verification.
tags:
  - audit
  - compliance
  - reporting
  - evidence
  - operators
---

# Compliance Reporting and Evidence Retrieval

Evidence retrieval, compliance dashboards, audit trail reconstruction, and tamper-proof storage. How to answer auditor questions with cryptographically signed evidence.

!!! tip "Audit Readiness"
    Auditors ask questions. You provide evidence chains. Query by date range, artifact type, or release version. Verify with cryptographic signatures. Prove compliance with immutable records.

---

## Evidence Retrieval for Audits

**Pattern**: Query evidence by date range, artifact type, or release version.

```bash
# Retrieve all evidence for Q1 2025 audit
aws s3 ls s3://audit-evidence/ --recursive | \
  awk '$1 >= "2025-01-01" && $1 <= "2025-03-31"' > q1-evidence-manifest.txt

# Download specific evidence bundle
aws s3 cp s3://audit-evidence/bundles/evidence-v1.7.0.tar.gz .
tar -xzf evidence-v1.7.0.tar.gz

# Verify bundle signature
cosign verify-blob --bundle evidence-v1.7.0.tar.gz.sig evidence-v1.7.0.tar.gz
```

---

## Compliance Dashboard Patterns

### Grafana + GitHub API

```python
# Dashboard query: PR approval rate
def get_pr_approval_rate(start_date, end_date):
    prs = gh_api(f"/repos/{repo}/pulls?state=closed&since={start_date}")
    approved = [pr for pr in prs if pr['review_decision'] == 'APPROVED']
    return len(approved) / len(prs) * 100
```

### Custom Dashboard with S3 Evidence

```python
# Query evidence from S3
import boto3
import json

s3 = boto3.client('s3')

def get_security_scan_summary(month):
    prefix = f"scans/{month}"
    objects = s3.list_objects_v2(Bucket='audit-evidence', Prefix=prefix)

    scans = []
    for obj in objects['Contents']:
        data = s3.get_object(Bucket='audit-evidence', Key=obj['Key'])
        scans.append(json.loads(data['Body'].read()))

    return {
        'total_scans': len(scans),
        'critical_vulns': sum(s['critical_count'] for s in scans),
        'compliance_rate': calculate_compliance(scans)
    }
```

---

## Audit Trail Reconstruction

**Scenario**: Auditor asks "How do you prove release v1.7.0 passed security scans?"

**Evidence Chain**:

1. **Workflow run log**: Proves workflow executed
   - `s3://audit-evidence/workflow-logs/run-123456/log.txt`

2. **Security scan results**: Proves scans passed
   - `s3://audit-evidence/scans/2025-01-15/trivy.json`
   - `s3://audit-evidence/scans/2025-01-15/scorecard.json`

3. **SLSA provenance**: Proves artifact built from specific commit
   - `s3://audit-evidence/sboms/v1.7.0/multiple.intoto.jsonl`

4. **PR approval**: Proves code review occurred
   - `s3://audit-evidence/pr-approvals/pr-456-approvals.json`

5. **Deployment attestation**: Proves artifact deployed to production
   - `s3://audit-evidence/deployments/production/v1.7.0/attestation.json`

**Verification Command**:

```bash
# Verify SLSA provenance
slsa-verifier verify-artifact readability_linux_amd64 \
  --provenance-path multiple.intoto.jsonl \
  --source-uri github.com/adaptive-enforcement-lab/readability

# Verify signature
cosign verify-blob --bundle evidence-v1.7.0.tar.gz.sig evidence-v1.7.0.tar.gz
```

---

## Tamper-Proof Evidence Storage

**S3 Bucket Configuration**:

```json
{
  "VersioningConfiguration": {
    "Status": "Enabled"
  },
  "ObjectLockConfiguration": {
    "ObjectLockEnabled": "Enabled",
    "Rule": {
      "DefaultRetention": {
        "Mode": "COMPLIANCE",
        "Years": 7
      }
    }
  }
}
```

**Why Object Lock**:

- **COMPLIANCE mode**: Cannot be deleted, even by root user
- **Versioning**: All changes retained, immutable audit trail
- **WORM** (Write Once Read Many): Evidence cannot be tampered with after upload

**Cryptographic Verification**:

```bash
# Generate SHA256 hash of evidence at upload time
sha256sum evidence-v1.7.0.tar.gz > evidence-v1.7.0.tar.gz.sha256

# Verify integrity during audit
sha256sum -c evidence-v1.7.0.tar.gz.sha256
```

---

## Related Patterns

- [Audit Evidence Collection](audit-evidence.md) - Main overview
- [Evidence Types](evidence-types.md) - What to collect
- [Collection Strategies](collection-strategies.md) - How to capture evidence
- [Implementation](implementation.md) - Complete workflow examples

---

*Auditors ask questions. You provide evidence chains. Query by date. Filter by type. Verify with cryptography. S3 Object Lock ensures immutability. Evidence cannot be tampered with. Compliance is provable.*
