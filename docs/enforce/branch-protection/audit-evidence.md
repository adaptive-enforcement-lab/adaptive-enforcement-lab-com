---
title: Audit Evidence Collection
description: >-
  Patterns for collecting and storing branch protection audit evidence.
  Automated collection, retention policies, and compliance documentation.
tags:
  - github
  - security
  - compliance
  - audit
  - operators
  - policy-enforcement
---

# Audit Evidence Collection

Auditors ask for proof. Configuration screenshots are not proof. Timestamped API snapshots with cryptographic verification are proof.

!!! warning "Configuration Without Evidence is Faith-Based Compliance"
    Claiming branch protection exists is one thing. Proving it existed at a specific time, continuously, without gaps, is another. Evidence collection bridges the gap.

Manual screenshots capture one moment. Automated collection captures every moment. Compliance requires continuous proof.

---

## What is Audit Evidence?

**Definition**: Timestamped, verifiable records proving branch protection rules existed and were enforced during a specific period.

**Required data**:

- Branch protection configuration (complete JSON)
- Timestamp of collection (ISO 8601 format with timezone)
- Repository metadata (name, visibility, default branch)
- Protection status (enabled/disabled, specific rules)
- Enforcement status (admins enforced, bypass grants)
- Collection source (API endpoint, automation system)
- Hash for tamper detection (SHA-256 of configuration)

**Why it matters**: SOC 2 Type II audits require continuous monitoring evidence. ISO 27001 requires access control documentation. PCI-DSS requires code review enforcement proof. Failed audits cost certifications.

---

## Evidence Collection Patterns

### Pattern 1: API Snapshot Collection

Direct GitHub API calls with timestamped storage.

```bash
#!/bin/bash
# collect-evidence.sh
ORG="my-org"
EVIDENCE_DIR="audit-evidence/$(date +%Y-%m)"
mkdir -p "${EVIDENCE_DIR}"

gh api --paginate "orgs/${ORG}/repos" --jq '.[] | select(.archived == false) | .name' | \
while read repo; do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  DEFAULT_BRANCH=$(gh api "repos/${ORG}/${repo}" --jq '.default_branch')

  EVIDENCE_FILE="${EVIDENCE_DIR}/${repo}-${TIMESTAMP}.json"

  gh api "repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" 2>/dev/null | \
    jq --arg repo "${ORG}/${repo}" \
       --arg branch "${DEFAULT_BRANCH}" \
       --arg timestamp "${TIMESTAMP}" \
       '{
         repository: $repo,
         branch: $branch,
         collected_at: $timestamp,
         protection: .
       }' > "${EVIDENCE_FILE}"

  # Generate hash for tamper detection
  SHA256=$(sha256sum "${EVIDENCE_FILE}" | cut -d' ' -f1)
  jq --arg hash "${SHA256}" '. + {evidence_hash: $hash}' "${EVIDENCE_FILE}" > "${EVIDENCE_FILE}.tmp"
  mv "${EVIDENCE_FILE}.tmp" "${EVIDENCE_FILE}"

  echo "✅ Collected: ${repo}"
done
```

**Use when**: Simple collection. File-based storage. Monthly compliance snapshots.

### Pattern 2: Workflow-Based Collection

GitHub Actions workflow for automated, scheduled evidence collection.

```yaml
# .github/workflows/audit-evidence-collection.yml
name: Audit Evidence Collection

on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly, Monday 2 AM UTC
  workflow_dispatch:

jobs:
  collect:
    runs-on: ubuntu-latest
    steps:
      - name: Generate GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.AUDIT_APP_ID }}
          private-key: ${{ secrets.AUDIT_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Collect evidence
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
          EVIDENCE_FILE="evidence-${TIMESTAMP}.json"

          gh api --paginate "orgs/${{ github.repository_owner }}/repos" \
            --jq '.[] | select(.archived == false) | {name, default_branch}' | \
          jq -s '.' > repos.json

          jq -r '.[] | "\(.name)|\(.default_branch)"' repos.json | while IFS='|' read repo branch; do
            gh api "repos/${{ github.repository_owner }}/${repo}/branches/${branch}/protection" 2>/dev/null || echo '{}'
          done | jq -s --arg timestamp "${TIMESTAMP}" \
            '{collected_at: $timestamp, repositories: .}' > "${EVIDENCE_FILE}"

      - name: Upload evidence artifact
        uses: actions/upload-artifact@v4
        with:
          name: audit-evidence-${{ github.run_id }}
          path: evidence-*.json
          retention-days: 2555  # 7 years for compliance
```

**Use when**: Automated collection. Centralized storage. Artifact retention required.

### Pattern 3: Database-Backed Collection

Store evidence in PostgreSQL for queryable audit trails.

```python
#!/usr/bin/env python3
# collect-to-database.py
import json
import hashlib
from datetime import datetime
import psycopg2

def collect_evidence(org, repo, branch, gh_token):
    """Collect and store branch protection evidence."""
    import requests

    headers = {"Authorization": f"Bearer {gh_token}"}
    url = f"https://api.github.com/repos/{org}/{repo}/branches/{branch}/protection"

    response = requests.get(url, headers=headers)
    protection = response.json() if response.status_code == 200 else {}

    evidence = {
        "repository": f"{org}/{repo}",
        "branch": branch,
        "collected_at": datetime.utcnow().isoformat() + "Z",
        "protection": protection,
        "status_code": response.status_code
    }

    evidence_json = json.dumps(evidence, sort_keys=True)
    evidence_hash = hashlib.sha256(evidence_json.encode()).hexdigest()
    evidence["evidence_hash"] = evidence_hash

    return evidence

def store_evidence(evidence, db_conn):
    """Store evidence in PostgreSQL."""
    with db_conn.cursor() as cursor:
        cursor.execute("""
            INSERT INTO branch_protection_evidence
            (repository, branch, collected_at, protection_config, evidence_hash)
            VALUES (%s, %s, %s, %s, %s)
        """, (
            evidence["repository"],
            evidence["branch"],
            evidence["collected_at"],
            json.dumps(evidence["protection"]),
            evidence["evidence_hash"]
        ))
    db_conn.commit()

# Schema
"""
CREATE TABLE branch_protection_evidence (
    id SERIAL PRIMARY KEY,
    repository VARCHAR(255) NOT NULL,
    branch VARCHAR(255) NOT NULL,
    collected_at TIMESTAMP WITH TIME ZONE NOT NULL,
    protection_config JSONB NOT NULL,
    evidence_hash VARCHAR(64) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_repository_date ON branch_protection_evidence(repository, collected_at);
"""
```

**Use when**: Historical queries required. Long-term retention. Compliance reporting dashboards.

---

## Evidence Formats

### Complete Snapshot Format

```json
{
  "repository": "org/api-service",
  "branch": "main",
  "collected_at": "2026-01-02T14:30:00Z",
  "collector": "github-actions",
  "collector_version": "1.2",
  "protection": {
    "required_status_checks": {
      "strict": true,
      "contexts": ["test", "lint", "security-scan"]
    },
    "enforce_admins": {"enabled": true},
    "required_pull_request_reviews": {
      "required_approving_review_count": 2,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true
    },
    "required_signatures": {"enabled": true},
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false
  },
  "compliance_tier": "maximum",
  "evidence_hash": "a7f5c8d3e9b2f1a4c6d8e0f3a5b7c9d1e3f5a7b9c1d3e5f7a9b1c3d5e7f9a1b3"
}
```

### Minimal Compliance Format

```json
{
  "repository": "org/api-service",
  "collected_at": "2026-01-02T14:30:00Z",
  "controls": {
    "code_review_required": true,
    "minimum_reviewers": 2,
    "admin_enforcement": true,
    "commit_signing": true,
    "status_checks": ["test", "security-scan"]
  },
  "evidence_hash": "b8e6d4f2a0c9e7b5d3f1a9c7e5b3d1f0e8d6c4b2a0f9e7d5c3b1a9f7e5d3c1b0"
}
```

---

## Storage and Retention

### File-Based Storage

Organize by month: `audit-evidence/YYYY-MM/repo-TIMESTAMP.json`

**Retention**: 7 years (SOC 2, PCI-DSS), 3 years (ISO 27001).

**Backup**: S3 with versioning. Glacier for long-term.

### Database Storage

PostgreSQL with JSONB for queryable trails:

```sql
SELECT repository, collected_at, protection_config
FROM branch_protection_evidence
WHERE repository = 'org/api-service' AND collected_at >= '2025-01-01'
ORDER BY collected_at DESC;
```

**Retention**: Monthly partitions. Archive after 3 years.

### Git-Based Storage

Commit evidence to audit repo for cryptographic verification via signed commits. Provides immutable history and distributed backup.

---

## Collection Frequency Patterns

**Daily collection**: Critical repositories (CDE, auth, payment systems). Schedule at `0 1 * * *`.

**Weekly collection**: Production services. Schedule at `0 2 * * 1` (Monday 2 AM UTC).

**Monthly collection**: All repositories. Schedule at `0 3 1 * *` (first of month).

**Event-driven collection**: Trigger on `repository_dispatch` events (protection changes, audit requests).

See workflow examples in Pattern 2 above for implementation details.

---

## Point-in-Time Verification

Query historical evidence to prove protection existed at specific date:

```sql
SELECT repository, collected_at, protection_config
FROM branch_protection_evidence
WHERE repository = 'org/api-service'
  AND collected_at <= '2025-12-01'
ORDER BY collected_at DESC LIMIT 1;
```

For file-based evidence, find closest timestamp to target date. See **[Verification Scripts](verification-scripts.md)** for complete verification tooling.

---

## Best Practices

**1. Automate collection**: Manual collection is unreliable. Schedule workflows for continuous evidence capture.

**2. Store immutably**: Use write-once storage (S3 Object Lock, Git signed commits) to prevent tampering.

**3. Include metadata**: Collector version, timestamp source, API response codes. Required for evidence verification.

**4. Hash evidence**: SHA-256 hash proves integrity. Include hash in evidence file itself.

**5. Separate collection from enforcement**: Use dedicated GitHub App for collection (read-only). Prevents enforcement failures from blocking evidence.

**6. Test restoration**: Verify you can query historical evidence. Test point-in-time verification before audits.

---

## Troubleshooting

**Evidence collection missing repositories**: GitHub App installation scope incomplete. Verify app installed organization-wide.

**Hash verification failing**: Evidence file modified post-collection. Investigate access logs. Use immutable storage.

**Gaps in evidence timeline**: Workflow failures during collection window. Check workflow run history. Implement retry logic.

**Evidence file too large**: Collecting all repositories in single file. Split by repository. Use streaming writes.

See **[Troubleshooting](troubleshooting.md)** for additional issues.

---

## Related Patterns

**Branch Protection**:

- **[Compliance Reporting](compliance-reporting.md)**: Framework-specific reports from evidence
- **[Verification Scripts](verification-scripts.md)**: Enhanced verification and validation
- **[Drift Detection](drift-detection.md)**: Real-time compliance monitoring
- **[Enforcement Workflows](enforcement-workflows.md)**: Automated remediation patterns
- **[Security Tiers](security-tiers.md)**: Tier-based compliance requirements

**General Audit & Compliance**:

- **[Audit Evidence Collection](../audit-compliance/audit-evidence.md)**: Main audit evidence patterns
- **[Evidence Types](../audit-compliance/evidence-types.md)**: Comprehensive evidence taxonomy
- **[Collection Strategies](../audit-compliance/collection-strategies.md)**: Evidence capture approaches

---

## Next Steps

1. Choose evidence collection pattern and deploy automated workflow (weekly minimum, daily for critical repos)
2. Configure retention policy (7 years SOC 2/PCI-DSS, 3 years ISO 27001)
3. Test point-in-time verification and generate compliance reports (see [Compliance Reporting](compliance-reporting.md))

---

*Evidence collection was automated. Every repository. Every week. Timestamped. Hashed. Immutable. Auditors requested proof. The dashboard showed seven years of continuous enforcement. Zero gaps. Perfect compliance. The evidence was irrefutable.*
