---
title: Exception Management
description: >-
  Patterns for managing permanent and temporary exceptions to branch protection rules.
  Formalized exception tracking with approval workflows and compliance documentation.
tags:
  - github
  - security
  - compliance
  - audit
  - operators
  - policy-enforcement
---

# Exception Management

Some repositories need different rules. Documentation sites don't need signed commits. Bot accounts can't do code owner reviews. Legacy systems have constraints.

!!! warning "Undocumented Exceptions are Policy Violations"
    Repository configured with weaker protection than tier requires. No approval record. No expiration date. No documented justification. Auditor flags as control failure. Document and track all exceptions.

Documented exceptions with approval, justification, and review cycles convert policy deviations into controlled variance.

---

## What are Exceptions?

**Exception**: Approved deviation from standard branch protection tier requirements, documented with justification, approval record, and periodic review requirement.

**Difference from bypass controls**: Bypasses disable protection temporarily for specific actions. Exceptions modify protection requirements permanently or for extended periods.

**Difference from emergency access**: Break-glass grants immediate elevated access during incidents. Exceptions are planned deviations approved in advance through formal process.

**Without exception management**: Repository requires Maximum tier. Bot-driven deployment workflow can't satisfy code owner reviews. Team disables code owner requirement. No approval. No documentation. Compliance violation.

**With exception management**: Team requests exception via documented workflow. Security approves with justification. Exception logged in configuration database. Quarterly review confirms exception still necessary. Audit trail complete.

---

## Exception Types

### Permanent Exceptions

**Definition**: Indefinite deviation from tier requirements due to fundamental technical or business constraints. Subject to periodic review.

**Common scenarios**:

- **Bot-driven workflows**: Automated workflows cannot satisfy interactive review requirements
- **Documentation repositories**: Public docs sites don't require signed commits or multiple reviewers
- **Legacy system constraints**: System cannot support modern cryptographic signing requirements
- **Architectural limitations**: Monorepo structure incompatible with CODEOWNERS-based review requirements

**Risk**: Permanent exceptions become forgotten gaps. Require annual review to confirm exception still necessary.

### Temporary Exceptions

**Definition**: Time-limited deviation granted for specific period (weeks/months). Automatically flagged for review at expiration.

**Common scenarios**:

- **Migration periods**: Transitioning from Standard to Enhanced tier. Grant 90-day exception during migration.
- **Tooling deployment**: New security scanning tool rolling out. Grant 60-day exception until all repositories onboarded.
- **Team onboarding**: New team unfamiliar with Maximum tier requirements. Grant 30-day exception during training period.
- **Vendor constraints**: Third-party integration requires relaxed protection. Exception expires when vendor updates integration.

**Benefit**: Built-in expiration prevents temporary exceptions from becoming permanent gaps.

---

## Exception Request Process

### GitHub Issues Request Pattern

Submit exception requests via GitHub Issue with required fields: repository, tier, exception type, duration, rules, justification, compensating controls, approver.

```yaml
# .github/ISSUE_TEMPLATE/branch-protection-exception.yml
name: Branch Protection Exception Request
description: Request approved exception to branch protection tier requirements
title: "[Exception] <repository-name>: <brief description>"
labels: ["branch-protection-exception", "pending-review"]
body:
  - type: input
    id: repository
    attributes:
      label: Repository
      placeholder: "org/repo-name"
    validations:
      required: true
  - type: dropdown
    id: exception_type
    attributes:
      label: Exception Type
      options:
        - Permanent (subject to annual review)
        - Temporary (specify duration)
  - type: textarea
    id: justification
    attributes:
      label: Technical Justification
      placeholder: "Why is this exception necessary? What technical constraint prevents standard tier compliance?"
    validations:
      required: true
  - type: textarea
    id: mitigations
    attributes:
      label: Compensating Controls
      placeholder: "What alternative controls mitigate the risk?"
    validations:
      required: true
```

### Automated Exception Processing

Process approved exception requests via workflow.

```yaml
# .github/workflows/exception-approval.yml
name: Process Exception Request

on:
  issues:
    types: [labeled]

jobs:
  process-exception:
    if: contains(github.event.issue.labels.*.name, 'exception-approved')
    runs-on: ubuntu-latest
    steps:
      - name: Generate GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.ENFORCEMENT_APP_ID }}
          private-key: ${{ secrets.ENFORCEMENT_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Record exception in database
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          cat > exception-record.json <<EOF
          {
            "exception_id": "exc-${{ github.event.issue.number }}",
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "repository": "PARSED_FROM_ISSUE",
            "requestor": "${{ github.event.issue.user.login }}",
            "approver": "${{ github.event.sender.login }}",
            "review_required_at": "$(date -u -d '+1 year' +%Y-%m-%dT%H:%M:%SZ)",
            "compliance_frameworks": ["SOC2-CC6.1", "ISO27001-A.14.2.5"]
          }
          EOF

          gh api --method PUT \
            "repos/${{ github.repository }}/contents/exceptions/exc-${{ github.event.issue.number }}.json" \
            -f message="Record exception" \
            -f content="$(base64 -w0 exception-record.json)"

      - name: Schedule annual review
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          gh issue create \
            --title "Exception Review: REPO" \
            --label "exception-review" \
            --body "Annual review required for exception exc-${{ github.event.issue.number }}"
```

---

## Exception Tracking

### Configuration Database

Track all active exceptions in centralized database.

```json
{
  "exceptions": [
    {
      "exception_id": "exc-1234",
      "repository": "org/docs-site",
      "assigned_tier": "Enhanced",
      "exception_type": "Permanent",
      "rules_excepted": ["required_signatures", "enforce_admins"],
      "justification": "Public docs. Signed commits not required. Admin override for emergency updates.",
      "compensating_controls": ["PRs require approval. Force-push prevented."],
      "approved_by": "security-lead",
      "approved_at": "2025-12-15T10:00:00Z",
      "review_required_at": "2026-12-15T10:00:00Z",
      "status": "active"
    }
  ]
}
```

### Discovery and Verification

Verify exception configuration matches approved exceptions.

```python
#!/usr/bin/env python3
# verify-exceptions.py
import json, sys
from github import Github
from datetime import datetime

def verify_exceptions(org, exceptions_file, gh_token):
    g = Github(gh_token)
    exceptions = json.load(open(exceptions_file))["exceptions"]
    violations = []

    for exc in [e for e in exceptions if e["status"] == "active"]:
        repo = g.get_repo(exc["repository"])
        protection = repo.get_branch(repo.default_branch).get_protection()

        # Verify exception matches approval
        if "required_signatures" in exc["rules_excepted"] and protection.required_signatures:
            violations.append({"exception_id": exc["exception_id"],
                             "violation": "Config mismatch"})

        # Check expiration for temporary exceptions
        if exc["exception_type"] == "Temporary":
            expiry = datetime.fromisoformat(exc["expires_at"].replace('Z', '+00:00'))
            if datetime.now(expiry.tzinfo) > expiry:
                violations.append({"exception_id": exc["exception_id"],
                                 "violation": "Expired"})
    return violations

if __name__ == "__main__":
    violations = verify_exceptions(sys.argv[1], sys.argv[2], sys.argv[3])
    if violations:
        print(json.dumps(violations, indent=2))
        sys.exit(1)
```

---

## Review and Renewal Process

### Periodic Review

Review all exceptions annually (permanent) or at expiration (temporary).

```yaml
# .github/workflows/exception-review.yml
name: Exception Review Reminder

on:
  schedule:
    - cron: '0 9 1 * *'  # 1st of every month at 9 AM UTC

jobs:
  review-exceptions:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout exception database
        uses: actions/checkout@v4

      - name: Find exceptions requiring review
        run: |
          jq -c '.exceptions[] | select(.review_required_at <= "'$(date -u +%Y-%m-%d)'")' \
            exceptions/database.json > review-needed.json

      - name: Create review issues
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          while IFS= read -r exception; do
            EXCEPTION_ID=$(echo "${exception}" | jq -r '.exception_id')
            REPO=$(echo "${exception}" | jq -r '.repository')

            gh issue create \
              --title "Exception Review Required: ${REPO}" \
              --label "exception-review" \
              --body "**Exception ID:** ${EXCEPTION_ID}

          ## Review Checklist
          - [ ] Exception still necessary
          - [ ] Compensating controls still effective
          - [ ] Alternative solutions evaluated

          ## Actions
          - [ ] **Renew**: Update review_required_at
          - [ ] **Revoke**: Apply standard tier protection
          - [ ] **Modify**: Update configuration"
          done < review-needed.json

```

---

## Integration with Enforcement

### Exception-Aware Drift Detection

Drift detection should account for approved exceptions.

```python
#!/usr/bin/env python3
# drift-detection-with-exceptions.py
import json
from github import Github

def check_drift_with_exceptions(repo_name, tier, exceptions_db, gh_token):
    g = Github(gh_token)
    protection = g.get_repo(repo_name).get_branch(g.get_repo(repo_name).default_branch).get_protection()
    tier_requirements = load_tier_requirements(tier)
    active_exceptions = [e for e in exceptions_db["exceptions"]
                        if e["repository"] == repo_name and e["status"] == "active"]
    violations = []

    for rule in ["enforce_admins", "required_signatures"]:
        if tier_requirements.get(rule):
            exception_exists = any(rule in e["rules_excepted"] for e in active_exceptions)
            has_protection = getattr(protection, rule, False)
            if not has_protection and not exception_exists:
                violations.append({"rule": rule, "status": "VIOLATION: No approved exception"})

    return violations
```

---

## Best Practices

**1. Require documented justification**: Generic "doesn't work" insufficient. Specify technical constraint and why standard tier impossible.

**2. Mandate compensating controls**: Exception reduces protection. Alternative controls mitigate risk. Document controls in approval.

**3. Default to temporary exceptions**: Grant 90-day temporary instead of permanent. Force re-evaluation after migration.

**4. Review exceptions annually**: Constraints change. Technology evolves. Annual review confirms exception still necessary.

**5. Track in version-controlled database**: Git repository, not spreadsheet. Full audit trail of approvals, modifications, revocations.

**6. Integrate with drift detection**: Enforcement workflows should recognize approved exceptions. Don't alert on authorized variance.

## Troubleshooting

**Exception request rejected**: Insufficient justification or compensating controls. Provide detailed technical explanation.

**Drift detected despite approved exception**: Exception not recorded in database. Verify record exists in `exceptions/database.json`.

**Temporary exception expired but unchanged**: Expiration workflow not configured. Manually apply tier protection.

**Exception review overdue**: Automated workflow not running. Check execution. Create review issue manually.

See **[Troubleshooting](troubleshooting.md)** for additional issues.

## Related Patterns

- **[Security Tiers](security-tiers.md)**: Tier requirements that exceptions deviate from
- **[Bypass Controls](bypass-controls.md)**: Temporary disablement vs permanent exceptions
- **[Emergency Access](emergency-access.md)**: Break-glass procedures for incidents
- **[Drift Detection](drift-detection.md)**: Exception-aware drift detection logic
- **[Compliance Reporting](compliance-reporting.md)**: Exception reporting for auditors
- **[Audit Evidence](audit-evidence.md)**: Exception approval and review evidence

---

## Next Steps

1. Create exception request issue template in `.github/ISSUE_TEMPLATE/`
2. Deploy exception approval workflow to organization repository
3. Initialize exception tracking database in version control
4. Configure quarterly exception review workflow
5. Update drift detection to incorporate exception database
6. Generate exception compliance report for auditors

---

*Exception requested. Security approved. Exception recorded in database. Annual review scheduled. Drift detection recognized exception. Audit trail complete. The exception was controlled.*
