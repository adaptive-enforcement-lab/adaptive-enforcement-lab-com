---
title: Verification Scripts
description: >-
  Verification scripts for audit preparation and continuous compliance.
  Automated validation of protection rules across repositories.
tags:
  - github
  - security
  - compliance
  - audit
  - operators
  - policy-enforcement
---

# Verification Scripts

Enforcement changes configuration. Verification proves configuration is correct. Auditors trust verification.

!!! tip "Verification Before Enforcement"
    Verification detects drift without changing state. Run verification before remediation. Understand the gap. Fix with precision.

Verification scripts answer two questions: Is protection configured correctly? Has it been correct continuously?

---

## Verification vs Enforcement

**Verification**: Read-only. Checks current state against desired state. Reports differences. Makes no changes.

**Enforcement**: Write operation. Applies desired state. Changes configuration. Logs actions.

Use verification for audit preparation. Use enforcement for remediation.

---

## Single Repository Verification

Quick check of one repository against tier requirements.

```bash
#!/bin/bash
# verify-repository.sh
REPO="${1}"
TIER="${2:-standard}"

echo "Verifying ${REPO} against ${TIER} tier..."

DEFAULT_BRANCH=$(gh api "repos/${REPO}" --jq '.default_branch')
PROTECTION=$(gh api "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" 2>/dev/null)

if [[ -z "${PROTECTION}" ]]; then
  echo "❌ FAIL: No branch protection configured"
  exit 1
fi

case "${TIER}" in
  standard) REQUIRED_REVIEWERS=1; REQUIRE_CODEOWNERS=false; ENFORCE_ADMINS=false; REQUIRE_SIGNATURES=false ;;
  enhanced) REQUIRED_REVIEWERS=2; REQUIRE_CODEOWNERS=true; ENFORCE_ADMINS=true; REQUIRE_SIGNATURES=false ;;
  maximum) REQUIRED_REVIEWERS=2; REQUIRE_CODEOWNERS=true; ENFORCE_ADMINS=true; REQUIRE_SIGNATURES=true ;;
  *) echo "❌ Unknown tier: ${TIER}"; exit 1 ;;
esac

EXIT_CODE=0

ACTUAL_REVIEWERS=$(echo "${PROTECTION}" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
if [[ "${ACTUAL_REVIEWERS}" -ge "${REQUIRED_REVIEWERS}" ]]; then
  echo "✅ Required reviewers: ${ACTUAL_REVIEWERS} (minimum ${REQUIRED_REVIEWERS})"
else
  echo "❌ Required reviewers: ${ACTUAL_REVIEWERS} (expected ${REQUIRED_REVIEWERS})"; EXIT_CODE=1
fi

ACTUAL_CODEOWNERS=$(echo "${PROTECTION}" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')
if [[ "${ACTUAL_CODEOWNERS}" == "${REQUIRE_CODEOWNERS}" ]]; then
  echo "✅ Code owner reviews: ${ACTUAL_CODEOWNERS}"
else
  echo "❌ Code owner reviews: ${ACTUAL_CODEOWNERS} (expected ${REQUIRE_CODEOWNERS})"; EXIT_CODE=1
fi

ACTUAL_ENFORCE_ADMINS=$(echo "${PROTECTION}" | jq -r '.enforce_admins.enabled // false')
if [[ "${ACTUAL_ENFORCE_ADMINS}" == "${ENFORCE_ADMINS}" ]]; then
  echo "✅ Admin enforcement: ${ACTUAL_ENFORCE_ADMINS}"
else
  echo "❌ Admin enforcement: ${ACTUAL_ENFORCE_ADMINS} (expected ${ENFORCE_ADMINS})"; EXIT_CODE=1
fi

if [[ "${REQUIRE_SIGNATURES}" == "true" ]]; then
  ACTUAL_SIGNATURES=$(echo "${PROTECTION}" | jq -r '.required_signatures.enabled // false')
  if [[ "${ACTUAL_SIGNATURES}" == "true" ]]; then
    echo "✅ Commit signatures: ${ACTUAL_SIGNATURES}"
  else
    echo "❌ Commit signatures: ${ACTUAL_SIGNATURES} (expected true)"; EXIT_CODE=1
  fi
fi

exit ${EXIT_CODE}
```

**Usage**: `./verify-repository.sh org/api-service enhanced`

---

## Organization-Wide Verification

Comprehensive validation across all repositories.

```python
#!/usr/bin/env python3
# verify-organization.py
import json, sys, requests, os
from typing import Dict, List

TIERS = {
    "standard": {"reviewers": 1, "codeowners": False, "admins": False, "sigs": False},
    "enhanced": {"reviewers": 2, "codeowners": True, "admins": True, "sigs": False},
    "maximum": {"reviewers": 2, "codeowners": True, "admins": True, "sigs": True}
}

def verify_tier(protection: Dict, tier: str) -> Dict:
    req = TIERS.get(tier, {})
    issues = []
    pr = protection.get("required_pull_request_reviews", {})

    if pr.get("required_approving_review_count", 0) < req.get("reviewers", 0):
        issues.append(f"Reviewers below minimum")
    if pr.get("require_code_owner_reviews", False) != req.get("codeowners", False):
        issues.append("Code owner review mismatch")
    if protection.get("enforce_admins", {}).get("enabled", False) != req.get("admins", False):
        issues.append("Admin enforcement mismatch")
    if req.get("sigs") and not protection.get("required_signatures", {}).get("enabled", False):
        issues.append("Signatures required")

    return {"compliant": len(issues) == 0, "issues": issues}

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--org", required=True)
    parser.add_argument("--tier-config", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    token = os.environ.get("GH_TOKEN")
    if not token: sys.exit("GH_TOKEN required")

    tier_config = json.load(open(args.tier_config))
    repos = []
    page = 1
    while True:
        r = requests.get(f"https://api.github.com/orgs/{args.org}/repos?per_page=100&page={page}",
                        headers={"Authorization": f"Bearer {token}"})
        data = r.json()
        if not data: break
        repos.extend([r["full_name"] for r in data if not r["archived"]])
        page += 1

    results = {"org": args.org, "total": len(repos), "compliant": 0, "repos": []}

    for repo in repos:
        tier = tier_config.get(repo, "standard")
        r = requests.get(f"https://api.github.com/repos/{repo}/branches/main/protection",
                        headers={"Authorization": f"Bearer {token}"})
        protection = r.json() if r.status_code == 200 else {}
        v = verify_tier(protection, tier) if protection else {"compliant": False, "issues": ["No protection"]}

        results["repos"].append({"name": repo, "tier": tier, "compliant": v["compliant"], "issues": v["issues"]})
        if v["compliant"]: results["compliant"] += 1; print(f"✅ {repo}")
        else: print(f"❌ {repo}: {', '.join(v['issues'])}")

    pct = (results["compliant"] / results["total"] * 100) if results["total"] > 0 else 0
    print(f"\nCompliance: {results['compliant']}/{results['total']} ({pct:.1f}%)")

    if args.output: json.dump(results, open(args.output, 'w'), indent=2)
    sys.exit(0 if results["compliant"] == results["total"] else 1)

if __name__ == "__main__":
    main()
```

**Usage**: `GH_TOKEN="${GITHUB_TOKEN}" python3 verify-organization.py --org my-org --tier-config tier-config.json --output results.json`

See **[Security Tiers](security-tiers.md)** for tier definitions.

---

## Point-in-Time Verification

Verify protection existed at specific date using historical evidence.

```python
#!/usr/bin/env python3
# verify-historical.py
import json
from datetime import datetime
from pathlib import Path

def verify_at_date(repository: str, target_date: str, evidence_dir: str, tier: str):
    from verify_organization import verify_tier
    target_dt = datetime.fromisoformat(target_date)
    matching = []

    for f in Path(evidence_dir).rglob(f"*{repository.replace('/', '-')}*.json"):
        try:
            evidence = json.load(open(f))
            collected = datetime.fromisoformat(evidence["collected_at"].replace('Z', '+00:00'))
            if collected <= target_dt: matching.append((collected, evidence))
        except: continue

    if not matching: return print(f"❌ No evidence for {repository} before {target_date}") or False
    matching.sort(reverse=True)
    evidence = matching[0][1]
    protection = evidence.get("protection", {})
    if not protection: return print(f"❌ No protection at {evidence['collected_at']}") or False

    result = verify_tier(protection, tier)
    if result["compliant"]: print(f"✅ {repository} compliant on {evidence['collected_at']}")
    else: print(f"❌ {repository} non-compliant: {', '.join(result['issues'])}")
    return result["compliant"]

if __name__ == "__main__":
    verify_at_date("org/api-service", "2025-12-01T00:00:00Z", "audit-evidence/", "enhanced")
```

**Use for**: Audit preparation. Proving continuous compliance. Historical investigation. See **[Audit Evidence](audit-evidence.md)**.

---

## Continuous Monitoring

Scheduled verification for ongoing compliance monitoring.

```yaml
# .github/workflows/compliance-verification.yml
name: Compliance Verification

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.VERIFICATION_APP_ID }}
          private-key: ${{ secrets.VERIFICATION_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Verify organization
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          python3 scripts/verify-organization.py \
            --org ${{ github.repository_owner }} \
            --tier-config config/tier-config.json \
            --output verification-results.json

      - name: Check threshold
        run: |
          PCT=$(jq -r '(.compliant / .total * 100)' verification-results.json)
          THRESHOLD=95
          if (( $(echo "$PCT < $THRESHOLD" | bc -l) )); then
            echo "❌ Compliance: ${PCT}% < ${THRESHOLD}%"
            exit 1
          fi

      - uses: actions/upload-artifact@v4
        with:
          name: compliance-verification-${{ github.run_id }}
          path: verification-results.json
          retention-days: 90
```

**Frequency**: Every 6 hours for production. Daily for non-critical.

---

## Audit Preparation

Generate comprehensive audit report combining current verification and historical evidence.

```bash
#!/bin/bash
# prepare-audit-report.sh
ORG="${1}"; START="${2}"; END="${3}"; EVIDENCE_DIR="${4:-audit-evidence}"
REPORT="audit-report-${ORG}-${START}-${END}.json"

gh api --paginate "orgs/${ORG}/repos" --jq '.[] | select(.archived == false) | .name' | while read repo; do
  EVIDENCE=$(find "${EVIDENCE_DIR}" -name "*${repo}*" -type f | wc -l)
  ./verify-repository.sh "${ORG}/${repo}" enhanced > /dev/null 2>&1
  echo "${ORG}/${repo},${?},${EVIDENCE}"
done > audit-data.csv

python3 -c "
import json, csv
data = {'organization': '${ORG}', 'period': {'start': '${START}', 'end': '${END}'}, 'repos': []}
with open('audit-data.csv') as f:
    for row in csv.reader(f):
        data['repos'].append({'name': row[0], 'compliant': row[1] == '0', 'evidence': int(row[2])})
data['summary'] = {'total': len(data['repos']), 'compliant': sum(1 for r in data['repos'] if r['compliant'])}
print(json.dumps(data, indent=2))
" > "${REPORT}"

jq '.summary' "${REPORT}"
```

**Use for**: SOC 2 audits. ISO 27001 recertification. PCI-DSS assessments. See **[Compliance Reporting](compliance-reporting.md)**.

---

## Best Practices

**1. Verify before enforcement**: Read-only verification identifies drift without risk. Understand gaps before remediation.

**2. Schedule regular verification**: Daily verification catches drift early. Continuous monitoring prevents compliance gaps.

**3. Set compliance thresholds**: 95% minimum for production. 100% for CDE repositories. Fail workflows below threshold.

**4. Archive verification results**: 90-day retention minimum. 7 years for compliance evidence. Artifact storage or S3.

**5. Separate verification from enforcement**: Different GitHub Apps. Prevents enforcement permissions from compromising read-only verification.

**6. Test verification scripts**: Run against known-good and known-bad configurations. Verify detection accuracy before production.

---

## Troubleshooting

**Verification shows false positives**: Normalization issue. Status check order differs. Hash-based comparison too strict. Use field-level comparison.

**Historical verification finds no evidence**: Evidence collection started after target date. Check evidence directory structure. Verify filename patterns.

**Organization-wide verification times out**: Too many repositories. Paginate API calls. Process in batches of 50. Increase workflow timeout.

**Compliance percentage fluctuates**: New repositories created without protection. Update tier configuration. Implement webhook triggers for new repos.

See **[Troubleshooting](troubleshooting.md)** for additional issues.

---

## Related Patterns

**Branch Protection**:

- **[Audit Evidence](audit-evidence.md)**: Evidence collection and storage
- **[Compliance Reporting](compliance-reporting.md)**: Framework-specific reports
- **[Drift Detection](drift-detection.md)**: Real-time configuration monitoring
- **[Enforcement Workflows](enforcement-workflows.md)**: Automated remediation
- **[Security Tiers](security-tiers.md)**: Tier requirement definitions

**General Audit & Compliance**:

- **[Audit Evidence Collection](../audit-compliance/audit-evidence.md)**: Main audit evidence patterns
- **[Compliance Reporting](../audit-compliance/compliance-reporting.md)**: General compliance reporting

---

## Next Steps

1. Deploy single-repository verification and configure tier mappings (tier-config.json)
2. Run organization-wide verification to identify compliance gaps
3. Deploy scheduled verification workflow (every 6 hours) and test historical verification (see [Enforcement Workflows](enforcement-workflows.md) for remediation)

---

*Verification ran continuously. Every six hours. Every repository. Drift detected within minutes. Compliance threshold: 98.7%. Auditors requested historical proof. Evidence archive queried. Point-in-time verification: 100% compliant. Continuous monitoring. Zero gaps. Perfect evidence.*
