---
title: Evidence Types for Audit Compliance
description: >-
  Six categories of audit evidence: branch protection, workflow logs, SBOMs, security scans, approvals, and deployments with collection patterns and retention policies.
tags:
  - audit
  - compliance
  - evidence
  - sdlc
  - operators
---

# Evidence Types for Audit Compliance

Six categories of evidence required for SDLC compliance audits. What to collect, how to capture it, and retention requirements.

!!! tip "Evidence Categories"
    Branch protection configurations prove security settings. Workflow logs prove execution. SBOMs prove supply chain transparency. Security scans prove vulnerability management. Approvals prove oversight. Deployments prove provenance.

---

## 1. Branch Protection Configurations

**What**: Repository branch protection rules exported as JSON.

**Why**: Proves enforcement of code review, status checks, and approval requirements.

**How to Collect**:

```bash
# Export branch protection rules
gh api repos/{owner}/{repo}/branches/main/protection > branch-protection-$(date +%Y%m%d).json
```

**GitHub Actions Pattern**:

```yaml
- name: Archive Branch Protection Rules
  run: |
    DATE=$(date +%Y%m%d)
    gh api repos/${{ github.repository }}/branches/main/protection \
      > "evidence/branch-protection-${DATE}.json"

- uses: actions/upload-artifact@v4
  with:
    name: branch-protection-evidence
    path: evidence/
    retention-days: 90
```

**Retention**: 1 year minimum (compliance requirement for most frameworks).

---

## 2. Workflow Run Logs and Artifacts

**What**: CI/CD workflow execution logs, test results, build artifacts.

**Why**: Proves builds ran successfully, tests passed, security scans executed.

**How to Collect**:

GitHub retains workflow logs for 90 days by default. For longer retention:

```yaml
- name: Archive Workflow Logs
  if: always()
  run: |
    gh run view ${{ github.run_id }} --log > workflow-log.txt

- uses: actions/upload-artifact@v4
  with:
    name: workflow-logs-${{ github.run_id }}
    path: workflow-log.txt
    retention-days: 365
```

**S3 Upload for Permanent Retention**:

```yaml
- name: Upload Evidence to S3
  run: |
    aws s3 cp workflow-log.txt \
      s3://audit-evidence/${{ github.repository }}/${{ github.run_id }}/ \
      --storage-class GLACIER_IR
```

**Retention**: 1 to 7 years depending on compliance framework (SOC 2: 1 year, HIPAA: 6 years, financial services: 7 years).

---

## 3. SBOM Archives

**What**: Software Bill of Materials in CycloneDX or SPDX format.

**Why**: Proves dependency tracking, vulnerability awareness, supply chain transparency.

**How to Collect**:

```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    format: cyclonedx-json
    output-file: sbom.cdx.json

- name: Archive SBOM
  run: |
    VERSION="${{ github.ref_name }}"
    aws s3 cp sbom.cdx.json \
      s3://audit-evidence/sboms/${VERSION}/sbom-${VERSION}.cdx.json
```

**Versioning Strategy**: One SBOM per release, timestamped, immutable.

**Retention**: Permanent (tied to software version lifecycle).

---

## 4. Security Scan Results

**What**: Trivy, Scorecard, CodeQL, Snyk scan outputs.

**Why**: Proves vulnerability scanning occurred, findings were addressed, compliance thresholds met.

**How to Collect**:

```yaml
- name: Run Security Scans
  run: |
    # Trivy container scan
    trivy image --format json --output trivy-results.json my-image:latest

    # Scorecard
    wget https://github.com/ossf/scorecard/releases/download/v5.0.0/scorecard_5.0.0_linux_amd64.tar.gz
    tar -xzf scorecard_5.0.0_linux_amd64.tar.gz
    ./scorecard --repo=https://github.com/${{ github.repository }} \
      --format=json > scorecard-results.json

- name: Upload Scan Results to S3
  run: |
    DATE=$(date +%Y%m%d)
    aws s3 cp trivy-results.json \
      s3://audit-evidence/scans/${DATE}/trivy.json
    aws s3 cp scorecard-results.json \
      s3://audit-evidence/scans/${DATE}/scorecard.json
```

**Retention**: 1 year minimum, permanent for major releases.

---

## 5. Approval Records

**What**: Pull request reviews, CODEOWNERS approvals, deployment approvals.

**Why**: Proves human oversight, peer review, segregation of duties.

**How to Collect**:

```bash
# Export PR review history
gh pr view 123 --json reviews,reviewDecision,latestReviews \
  > pr-123-approvals.json
```

**GitHub Actions Pattern**:

```yaml
- name: Archive PR Approval Evidence
  run: |
    gh pr view ${{ github.event.pull_request.number }} \
      --json reviews,reviewDecision,latestReviews,commits \
      > evidence/pr-${{ github.event.pull_request.number }}-approvals.json

    aws s3 cp evidence/ s3://audit-evidence/pr-approvals/ --recursive
```

**Retention**: 3 years (typical compliance requirement for access control evidence).

---

## 6. Deployment Attestations

**What**: SLSA provenance, deployment timestamps, environment records.

**Why**: Proves artifacts deployed to production are the same ones built from source.

**How to Collect**:

```yaml
- name: Generate Deployment Attestation
  run: |
    cat <<EOF > deployment-attestation.json
    {
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "environment": "${{ inputs.environment }}",
      "version": "${{ github.ref_name }}",
      "commit": "${{ github.sha }}",
      "artifact": "${{ inputs.image }}",
      "slsa_provenance": "multiple.intoto.jsonl",
      "deployed_by": "${{ github.actor }}"
    }
    EOF

    aws s3 cp deployment-attestation.json \
      s3://audit-evidence/deployments/${{ inputs.environment }}/${{ github.ref_name }}/
```

**Retention**: Permanent (tied to production deployments).

---

## Related Patterns

- [Audit Evidence Collection](audit-evidence.md) - Main overview
- [Collection Strategies](collection-strategies.md) - How to capture evidence
- [Compliance Reporting](compliance-reporting.md) - How to retrieve and present evidence

---

*Six evidence types. Each proves a compliance control. Branch protection proves security settings. Workflow logs prove execution. SBOMs prove transparency. Scans prove vulnerability management. Approvals prove oversight. Deployments prove provenance.*
