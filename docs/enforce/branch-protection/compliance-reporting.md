---
title: Compliance Reporting
description: >-
  Automated reporting patterns for SOC 2, ISO 27001, and PCI-DSS.
  Compliance evidence generation and audit preparation.
tags:
  - github
  - security
  - compliance
  - audit
  - operators
  - policy-enforcement
---

# Compliance Reporting

Auditors want specific answers to framework-specific questions. Generic configuration dumps are noise. Framework-mapped evidence is signal.

!!! tip "Compliance is Evidence + Mapping"
    Collecting evidence proves controls exist. Mapping evidence to compliance frameworks proves controls satisfy requirements. Reports bridge the gap.

Manual report generation takes weeks. Automated generation takes seconds. Compliance windows close fast.

---

## Framework Requirements

### SOC 2 Type II

**Trust Service Criteria CC6.1**: Change control requires code review before production deployment.

**Branch protection evidence**:

- Required pull request reviews enabled (minimum 1 reviewer)
- Dismiss stale reviews on new commits
- Status checks required (CI tests, security scans)
- Admin enforcement (no bypass for administrators)

**Reporting period**: Continuous monitoring. Evidence collection throughout audit period (typically 6-12 months).

### ISO 27001 (A.14.2.5)

**Control A.14.2.5**: Secure system engineering principles require peer review for critical changes.

**Branch protection evidence**:

- Pull request workflow enforced
- Code owner reviews for critical paths
- Audit trail of all protection changes
- Protection status at specific points in time

**Reporting period**: Annual recertification. Evidence from past 12 months.

### PCI-DSS Requirement 6.3.2

**Requirement 6.3.2**: Code changes reviewed by individuals other than originating developer, with knowledge of code review techniques and secure coding practices.

**Branch protection evidence**:

- Required approving review count (minimum 1, recommend 2)
- Code owner reviews enforced (demonstrates expertise requirement)
- Review enforcement for all repositories in Cardholder Data Environment (CDE)
- Status checks include security scanning (SAST, dependency check)

**Reporting period**: Quarterly scans. Annual assessment. Evidence from past 12 months.

---

## Evidence Mapping

Map collected evidence to framework requirements:

```python
#!/usr/bin/env python3
# map-evidence.py
def map_to_soc2(protection_config):
    """Map branch protection config to SOC 2 CC6.1 controls."""
    pr_reviews = protection_config.get("required_pull_request_reviews", {})
    enforce_admins = protection_config.get("enforce_admins", {}).get("enabled", False)
    status_checks = protection_config.get("required_status_checks", {})

    controls = []
    if pr_reviews.get("required_approving_review_count", 0) >= 1:
        controls.append({"control": "Peer review", "status": "PASS"})
    if pr_reviews.get("dismiss_stale_reviews"):
        controls.append({"control": "Stale dismissal", "status": "PASS"})
    if enforce_admins:
        controls.append({"control": "Admin enforcement", "status": "PASS"})
    if status_checks.get("contexts"):
        controls.append({"control": "Automated testing", "status": "PASS"})

    return {"framework": "SOC 2", "control": "CC6.1", "controls": controls}
```

See **[Audit Evidence](audit-evidence.md)** for evidence collection patterns.

---

## Automated Report Generation

### SOC 2 Compliance Report

Generate SOC 2 compliance report from evidence database:

```python
#!/usr/bin/env python3
# generate-soc2-report.py
import json
from datetime import datetime, timedelta

def generate_soc2_report(evidence_db, start_date, end_date):
    """Generate SOC 2 Type II compliance report."""
    repositories = query_repositories(evidence_db, start_date, end_date)

    report = {
        "report_type": "SOC 2 Type II",
        "control": "CC6.1",
        "audit_period": {"start": start_date.isoformat(), "end": end_date.isoformat()},
        "summary": {"total": 0, "compliant": 0, "percentage": 0},
        "repositories": []
    }

    for repo in repositories:
        evidence = get_latest_evidence(evidence_db, repo, end_date)
        compliance = check_soc2_compliance(evidence)

        report["repositories"].append({
            "name": repo,
            "status": "COMPLIANT" if compliance["compliant"] else "NON_COMPLIANT",
            "controls": compliance["controls"]
        })

        report["summary"]["total"] += 1
        if compliance["compliant"]:
            report["summary"]["compliant"] += 1

    total = report["summary"]["total"]
    compliant = report["summary"]["compliant"]
    report["summary"]["percentage"] = (compliant / total * 100) if total > 0 else 0
    return report

def check_soc2_compliance(evidence):
    """Check if evidence satisfies SOC 2 CC6.1."""
    p = evidence.get("protection", {})
    pr = p.get("required_pull_request_reviews", {})

    checks = {
        "peer_review": pr.get("required_approving_review_count", 0) >= 1,
        "stale_dismissal": pr.get("dismiss_stale_reviews", False),
        "admin_enforcement": p.get("enforce_admins", {}).get("enabled", False),
        "automated_testing": len(p.get("required_status_checks", {}).get("contexts", [])) > 0
    }

    return {"compliant": all(checks.values()), "controls": checks}
```

### ISO 27001 Compliance Report

```bash
#!/bin/bash
# generate-iso27001-report.sh
ORG="my-org"
START_DATE="2025-01-01"
END_DATE="2025-12-31"

echo "ISO 27001 Control A.14.2.5 Compliance Report"
echo "Organization: ${ORG}"
echo "Period: ${START_DATE} to ${END_DATE}"
echo ""
echo "Repository,PR Review Required,Code Owner Review,Protection Status,Compliant"

gh api --paginate "orgs/${ORG}/repos" --jq '.[] | select(.archived == false) | .name' | \
while read repo; do
  DEFAULT_BRANCH=$(gh api "repos/${ORG}/${repo}" --jq '.default_branch')
  PROTECTION=$(gh api "repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" 2>/dev/null || echo '{}')

  PR_REQUIRED=$(echo "${PROTECTION}" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
  CODEOWNER_REQUIRED=$(echo "${PROTECTION}" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')

  COMPLIANT="NO"
  if [[ "${PR_REQUIRED}" -ge 1 ]] && [[ "${CODEOWNER_REQUIRED}" == "true" ]]; then
    COMPLIANT="YES"
  fi

  echo "${repo},${PR_REQUIRED},${CODEOWNER_REQUIRED},ENABLED,${COMPLIANT}"
done
```

### PCI-DSS Compliance Report

```python
#!/usr/bin/env python3
# generate-pci-dss-report.py
def generate_pci_dss_report(evidence_db, cde_repositories):
    """Generate PCI-DSS Requirement 6.3.2 compliance report."""
    report = {
        "report_type": "PCI-DSS v4.0",
        "requirement": "6.3.2",
        "scope": {"total": len(cde_repositories), "compliant": 0},
        "repositories": []
    }

    for repo in cde_repositories:
        evidence = get_latest_evidence(evidence_db, repo)
        compliance = check_pci_dss_compliance(evidence)

        report["repositories"].append({
            "name": repo,
            "status": "COMPLIANT" if compliance["compliant"] else "NON_COMPLIANT",
            "issues": compliance["issues"]
        })

        if compliance["compliant"]:
            report["scope"]["compliant"] += 1

    return report

def check_pci_dss_compliance(evidence):
    """Check if evidence satisfies PCI-DSS 6.3.2."""
    p = evidence.get("protection", {})
    pr = p.get("required_pull_request_reviews", {})

    reviewers = pr.get("required_approving_review_count", 0)
    code_owners = pr.get("require_code_owner_reviews", False)
    contexts = p.get("required_status_checks", {}).get("contexts", [])
    security_scan = any("security" in c.lower() or "sast" in c.lower() for c in contexts)

    issues = []
    if reviewers < 1: issues.append("Minimum 1 reviewer required")
    if not code_owners: issues.append("Code owner review required")
    if not security_scan: issues.append("Security scanning required")

    return {"compliant": reviewers >= 1 and code_owners and security_scan, "issues": issues}
```

---

## Report Distribution

### Workflow-Based Report Generation

Automated monthly compliance reporting:

```yaml
# .github/workflows/compliance-reporting.yml
name: Monthly Compliance Reporting

on:
  schedule:
    - cron: '0 8 1 * *'  # First day of month, 8 AM UTC
  workflow_dispatch:
    inputs:
      frameworks:
        description: 'Frameworks to report (comma-separated: soc2,iso27001,pci-dss)'
        default: 'soc2,iso27001,pci-dss'

jobs:
  generate-reports:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout reporting scripts
        uses: actions/checkout@v4

      - name: Generate GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.COMPLIANCE_APP_ID }}
          private-key: ${{ secrets.COMPLIANCE_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Generate SOC 2 report
        if: contains(github.event.inputs.frameworks || 'soc2', 'soc2')
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          python3 scripts/generate-soc2-report.py \
            --org ${{ github.repository_owner }} \
            --output reports/soc2-$(date +%Y-%m).json

      - name: Generate ISO 27001 report
        if: contains(github.event.inputs.frameworks || 'iso27001', 'iso27001')
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          bash scripts/generate-iso27001-report.sh > reports/iso27001-$(date +%Y-%m).csv

      - name: Generate PCI-DSS report
        if: contains(github.event.inputs.frameworks || 'pci-dss', 'pci-dss')
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          python3 scripts/generate-pci-dss-report.py \
            --cde-repos-file config/cde-repositories.txt \
            --output reports/pci-dss-$(date +%Y-%m).json

      - name: Upload reports
        uses: actions/upload-artifact@v4
        with:
          name: compliance-reports-${{ github.run_id }}
          path: reports/
          retention-days: 2555  # 7 years
```

---

## Best Practices

**1. Automate report generation**: Monthly scheduled workflows ensure reports ready before audits. Manual generation risks delays.

**2. Map evidence to specific controls**: Generic configuration dumps fail audits. Framework-specific mappings pass audits.

**3. Include temporal evidence**: Point-in-time verification proves continuous compliance. Single snapshots prove nothing about duration.

**4. Store reports immutably**: S3 with Object Lock. Git with signed commits. Auditors verify report integrity.

**5. Generate multiple formats**: JSON for automation. CSV for spreadsheets. PDF for auditors. Dashboards for executives.

**6. Test report generation before audits**: Dry runs reveal gaps. Fix evidence collection issues before audit windows open.

---

## Troubleshooting

**Report shows non-compliant repositories**: Query historical evidence. Verify protection existed during audit period. Recent changes may not reflect historical state.

**Missing repositories in report**: Verify evidence collection scope. Check GitHub App installation coverage. Archived repositories excluded by default.

**Report generation timeout**: Split by framework. Paginate repository queries. Process in batches for large organizations.

**Compliance percentage below threshold**: Review tier assignments. Verify expected security tier matches actual configuration. See **[Security Tiers](security-tiers.md)**.

See **[Troubleshooting](troubleshooting.md)** for additional issues.

---

## Related Patterns

**Branch Protection**:

- **[Audit Evidence](audit-evidence.md)**: Evidence collection and storage patterns
- **[Verification Scripts](verification-scripts.md)**: Enhanced verification tooling
- **[Security Tiers](security-tiers.md)**: Tier-to-framework mapping
- **[Multi-Repo Management](multi-repo-management.md)**: Organization-wide enforcement
- **[Drift Detection](drift-detection.md)**: Continuous compliance monitoring

**General Audit & Compliance**:

- **[Audit Evidence Collection](../audit-compliance/audit-evidence.md)**: Main audit evidence patterns
- **[Compliance Reporting](../audit-compliance/compliance-reporting.md)**: General compliance reporting approaches
- **[Implementation](../audit-compliance/implementation.md)**: Complete workflow examples

---

## Next Steps

1. Deploy evidence collection workflows (weekly minimum, see audit-evidence.md)
2. Configure framework mappings (identify CDE repos for PCI-DSS, tier mappings for all)
3. Generate test reports (verify evidence covers audit period requirements)
4. Schedule automated reporting (monthly minimum, before audit windows)
5. Review reports with compliance team (verify mappings satisfy auditors)

---

*Compliance reports generated automatically. SOC 2 showed 100% CC6.1 coverage. ISO 27001 demonstrated A.14.2.5 controls. PCI-DSS verified CDE enforcement. Auditors reviewed the evidence. No findings. Zero gaps. Certification renewed.*
