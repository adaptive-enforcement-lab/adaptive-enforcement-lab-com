---
description: >-
  Audit evidence collection for SDLC hardening. Branch protection archival, PR review records, commit signature tracking, workflow logs, and SBOM storage for compliance validation.
tags:
  - audit
  - evidence
  - compliance
  - archival
  - documentation
---

# Phase 4: Audit Evidence Collection

Document everything. Auditors will ask. Automated collection ensures evidence exists when needed.

---

## Branch Protection Configuration

### Monthly Archive

- [ ] **Archive branch protection settings monthly**

  ```bash
  #!/bin/bash
  # scripts/archive-branch-protection.sh

  DATE=$(date +%Y-%m-%d)
  mkdir -p evidence/$DATE

  gh repo list org --limit 1000 --json name --jq '.[].name' | while read repo; do
    gh api repos/org/$repo/branches/main/protection \
      > evidence/$DATE/$repo-branch-protection.json 2>/dev/null || echo "{}" > evidence/$DATE/$repo-branch-protection.json
  done

  gsutil -m cp -r evidence/$DATE gs://audit-evidence/

  ```

  **How to validate**:

  ```bash
  gsutil ls gs://audit-evidence/2025-01-01/ | wc -l
  # Should show one file per repository
  ```

  **Why it matters**: Auditors will ask "prove branch protection was enabled on 2025-01-01". Archived config proves it.

!!! tip "Tamper-Proof Storage"
    Use cloud storage with object versioning and bucket locks. This prevents accidental deletion and provides cryptographic proof of evidence integrity.

---

## Pull Request Review Records

### Review Metadata Archive

- [ ] **Archive merged PRs with review metadata**

  ```bash
  #!/bin/bash
  # scripts/archive-pr-reviews.sh

  DATE=$(date +%Y-%m-%d)

  gh api 'repos/org/repo/pulls?state=closed&base=main&per_page=100' \
    --paginate \
    --jq '.[] | select(.merged_at != null) | {
      number,
      title,
      merged_at,
      review_count: (.reviews | length),
      approvers: [.reviews[] | select(.state == "APPROVED") | .user.login],
      signed: .commit.commit.verification.verified
    }' > evidence/$DATE/merged-prs.json

  gsutil cp evidence/$DATE/merged-prs.json gs://audit-evidence/$DATE/

  ```

  **How to validate**:

  ```bash
  gsutil cp gs://audit-evidence/2025-01-01/merged-prs.json .
  jq '.[] | .approvers' merged-prs.json
  # Should show reviewers for each PR
  ```

  **Why it matters**: Proves each merged PR had at least one review. Auditors sample PRs and verify reviews actually happened.

---

## Commit Signature Coverage

### Signature Tracking

- [ ] **Calculate and track signature coverage**

  ```bash
  #!/bin/bash
  # scripts/calculate-signature-coverage.sh

  START_DATE=$1  # YYYY-MM-DD
  END_DATE=$2

  TOTAL=$(git log --since="$START_DATE" --until="$END_DATE" --oneline | wc -l)
  SIGNED=$(git log --since="$START_DATE" --until="$END_DATE" --pretty=format:'%G?' | grep -c '^G')

  COVERAGE=$((SIGNED * 100 / TOTAL))
  echo "Signature coverage for $START_DATE to $END_DATE: $COVERAGE% ($SIGNED/$TOTAL)"

  ```

  **How to validate**:

  ```bash
  ./scripts/calculate-signature-coverage.sh 2025-01-01 2025-01-31
  # Should output: Signature coverage for 2025-01-01 to 2025-01-31: 100% (145/145)
  ```

  **Why it matters**: Auditors want 100% signature coverage. Tracking monthly proves commitment and identifies gaps.

---

## Workflow Run Logs

### CI/CD Execution Archive

- [ ] **Archive workflow run logs and artifacts**

  ```yaml
  # .github/workflows/archive-logs.yml
  name: Archive Workflow Logs
  on:
    schedule:
      - cron: '0 1 1 * *'  # Monthly

  jobs:
    archive:
      runs-on: ubuntu-latest
      steps:
        - name: Get workflow runs
          env:
            GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          run: |
            DATE_MONTH=$(date +%Y-%m)
            gh api repos/org/repo/actions/runs \
              --jq '.workflow_runs[] | select(.created_at | startswith("'$DATE_MONTH'"))' \
              > workflow-runs-$DATE_MONTH.json

        - name: Upload to evidence storage
          run: |
            gsutil cp workflow-runs-*.json gs://audit-evidence/$(date +%Y-%m)/

  ```

  **How to validate**:

  ```bash
  gsutil ls gs://audit-evidence/2025-01/workflow-runs*.json
  # Should list workflow run records
  ```

  **Why it matters**: Logs prove security checks ran. Auditors will verify scan results and test outcomes.

---

## SBOM and Security Scan Archive

### Release Artifact Evidence

- [ ] **Archive SBOMs and scan results for every release**

  ```yaml
  - name: Archive evidence
    if: startsWith(github.ref, 'refs/tags/')
    run: |
      mkdir -p evidence/releases/$(date +%Y-%m)
      cp sbom.json evidence/releases/$(date +%Y-%m)/sbom-${{ github.sha }}.json
      cp trivy-report.json evidence/releases/$(date +%Y-%m)/scan-${{ github.sha }}.json
      gsutil -m cp -r evidence/releases gs://audit-evidence/

  ```

  **How to validate**:

  ```bash
  gsutil ls gs://audit-evidence/releases/2025-01/sbom-*.json | head -5
  # Should list multiple SBOMs
  ```

  **Why it matters**: SBOMs and scans prove what dependencies are in production and that vulnerabilities were checked.

---

## Common Issues and Solutions

**Issue**: Evidence storage costs are high

**Solution**: Use lifecycle policies to archive to cold storage:

```bash
gsutil lifecycle set lifecycle-config.json gs://audit-evidence

# lifecycle-config.json
{
  "rule": [
    {
      "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
      "condition": {"age": 365}
    }
  ]
}
```

**Issue**: Evidence retrieval takes too long during audit

**Solution**: Create index files for fast lookup:

```bash
# Generate monthly index
find evidence/ -type f -name "*.json" | while read file; do
  echo "$file,$(stat -c%Y $file),$(wc -l < $file)" >> evidence/index.csv
done
```

---

## Related Patterns

- **[Compliance Validation](compliance.md)** - OpenSSF Scorecard, SLSA verification
- **[Audit Simulation](audit-simulation.md)** - Mock audit timeline
- **[Phase 4 Overview →](index.md)** - Advanced phase summary

---

*Evidence collected. Archives automated. Historical data preserved. Audit readiness achieved.*
