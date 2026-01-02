---
title: Drift Detection
description: >-
  Patterns for detecting and remediating branch protection drift.
  Automated monitoring, comparison algorithms, and restoration workflows.
tags:
  - github
  - security
  - automation
  - compliance
  - operators
  - policy-enforcement
  - github-apps
---

# Drift Detection

Drift is inevitable. Developers disable protection during incidents. Admins bypass rules for emergency fixes. Detection must be continuous.

!!! warning "Detection Without Remediation is Reporting"
    Finding drift is not enough. Automated remediation closes the gap between detection and compliance.

Manual verification happens weekly. Drift happens hourly. Automated detection catches changes in minutes.

---

## What is Drift?

**Configuration drift**: Actual branch protection differs from desired state.

**Common sources**:

- Manual changes via GitHub UI (disable protection for "quick fix")
- Repository transfer from external organization (inherits no protection)
- Admin bypass for emergency access (protection never restored)
- Terraform state out of sync (manual changes override IaC)
- New branch created without protection rules
- Partial rule application (some settings changed, others preserved)

**Impact**: Security gaps. Failed audits. Unreviewed code in production. Unsigned commits merged.

---

## Detection Approaches

### Approach 1: Field-Level Comparison

Compare each protection field against desired state for precise drift identification.

```python
def detect_field_drift(current, desired):
    """Compare individual fields for precise drift identification."""
    drift = {}

    # Required reviewers
    current_reviewers = current.get('required_pull_request_reviews', {}).get('required_approving_review_count', 0)
    desired_reviewers = desired.get('required_pull_request_reviews', {}).get('required_approving_review_count', 0)
    if current_reviewers < desired_reviewers:
        drift['required_reviewers'] = {'current': current_reviewers, 'desired': desired_reviewers, 'severity': 'high'}

    # Admin enforcement
    if desired.get('enforce_admins') and not current.get('enforce_admins', {}).get('enabled', False):
        drift['enforce_admins'] = {'severity': 'critical'}

    # Required signatures
    if desired.get('required_signatures') and not current.get('required_signatures', {}).get('enabled', False):
        drift['required_signatures'] = {'severity': 'critical'}

    # Status checks
    current_checks = set(current.get('required_status_checks', {}).get('contexts', []))
    desired_checks = set(desired.get('required_status_checks', {}).get('contexts', []))
    missing = desired_checks - current_checks
    if missing:
        drift['status_checks'] = {'missing': list(missing), 'severity': 'medium'}

    return drift
```

**Use when**: Partial drift expected. Selective remediation required. Detailed audit trail needed.

### Approach 2: Tier Compliance Verification

Verify repository meets minimum tier requirements.

```python
TIER_REQUIREMENTS = {
    'standard': {'min_reviewers': 1, 'enforce_admins': False, 'required_signatures': False},
    'enhanced': {'min_reviewers': 2, 'enforce_admins': True, 'required_signatures': False, 'code_owner_reviews': True},
    'maximum': {'min_reviewers': 2, 'enforce_admins': True, 'required_signatures': True, 'last_push_approval': True}
}

def verify_tier_compliance(current, tier):
    """Check if current protection meets tier minimum requirements."""
    requirements = TIER_REQUIREMENTS.get(tier, TIER_REQUIREMENTS['standard'])
    violations = []

    reviews = current.get('required_pull_request_reviews', {})
    if reviews.get('required_approving_review_count', 0) < requirements['min_reviewers']:
        violations.append(f"Insufficient reviewers: < {requirements['min_reviewers']}")

    if requirements['enforce_admins'] and not current.get('enforce_admins', {}).get('enabled', False):
        violations.append("Admin enforcement disabled")

    if requirements['required_signatures'] and not current.get('required_signatures', {}).get('enabled', False):
        violations.append("Required signatures disabled")

    if requirements.get('code_owner_reviews') and not reviews.get('require_code_owner_reviews', False):
        violations.append("Code owner reviews not required")

    return {'compliant': len(violations) == 0, 'violations': violations, 'tier': tier}
```

**Use when**: Strict tier compliance required. Binary compliance reporting needed.

### Approach 3: Hash-Based Detection

Calculate configuration hash for fast change detection.

```python
import hashlib
import json

def calculate_protection_hash(protection):
    """Generate hash of protection configuration for change detection."""
    normalized = {
        'required_approving_review_count': protection.get('required_pull_request_reviews', {}).get('required_approving_review_count', 0),
        'enforce_admins': protection.get('enforce_admins', {}).get('enabled', False),
        'required_signatures': protection.get('required_signatures', {}).get('enabled', False),
        'status_checks': sorted(protection.get('required_status_checks', {}).get('contexts', []))
    }
    return hashlib.sha256(json.dumps(normalized, sort_keys=True).encode()).hexdigest()

def detect_hash_drift(current, desired):
    """Fast drift detection via hash comparison."""
    return {
        'drift_detected': calculate_protection_hash(current) != calculate_protection_hash(desired),
        'current_hash': calculate_protection_hash(current),
        'desired_hash': calculate_protection_hash(desired)
    }
```

**Use when**: Scanning hundreds of repositories. Quick drift detection needed. Detailed analysis deferred.

---

## Detection Timing Patterns

### Real-Time Webhook Detection

Monitor branch protection events as they occur.

**Webhook events**: `branch_protection_rule.created`, `branch_protection_rule.edited`, `branch_protection_rule.deleted`

**Response time**: < 1 minute from change to detection.

See **[Enforcement Workflows](enforcement-workflows.md)** for webhook-triggered implementation.

### Scheduled Compliance Scan

Periodic verification across all repositories.

```bash
#!/bin/bash
# Scheduled drift detection scan
ORG="my-org"
CONFIG_FILE="config/branch-protection.json"

gh api --paginate "orgs/${ORG}/repos" --jq '.[] | select(.archived == false) | .name' | \
while read repo; do
  TIER=$(jq -r ".repositories[\"${ORG}/${repo}\"].tier // \"standard\"" "${CONFIG_FILE}")
  DEFAULT_BRANCH=$(gh api "repos/${ORG}/${repo}" --jq '.default_branch')

  CURRENT=$(gh api "repos/${ORG}/${repo}/branches/${DEFAULT_BRANCH}/protection" 2>/dev/null || echo '{}')

  if python3 detect-drift.py --current <(echo "${CURRENT}") --tier "${TIER}" --repo "${ORG}/${repo}"; then
    echo "✅ OK: ${repo}"
  else
    echo "❌ DRIFT: ${repo} (tier: ${TIER})"
  fi
done
```

**Scan frequency**: Standard tier (24 hours), Enhanced tier (6 hours), Maximum tier (1 hour).

**Use when**: Backup verification. Webhook failures. Bulk compliance reporting.

### Event-Driven Detection

Trigger detection on repository lifecycle events.

```yaml
on:
  repository:
    types: [created, transferred]
  push:
    branches: [main]
```

**Repository created**: Apply tier protection immediately. **Repository transferred**: Re-apply organization protection rules.

---

## Advanced Detection Scenarios

### Normalization for False Positive Prevention

GitHub API returns fields in different formats. Normalize before comparison.

```python
def normalize_protection(raw_protection):
    """Normalize API response to prevent false positives."""
    normalized = {}

    # Handle null vs empty array
    contexts = raw_protection.get('required_status_checks', {}).get('contexts')
    normalized['status_checks'] = contexts if contexts else []

    # Handle boolean vs object with 'enabled' field
    admins = raw_protection.get('enforce_admins')
    normalized['enforce_admins'] = admins.get('enabled', False) if isinstance(admins, dict) else bool(admins)

    return normalized
```

**Prevents**: `null` vs `[]` mismatches. Object vs boolean comparison errors. API version differences.

### Cascading Dependency Detection

Branch protection depends on external resources (CODEOWNERS, teams).

```python
def detect_cascading_drift(repo, protection):
    """Detect drift in dependencies."""
    issues = []

    # Verify CODEOWNERS exists if required
    if protection.get('required_pull_request_reviews', {}).get('require_code_owner_reviews'):
        try:
            get_file(repo, '.github/CODEOWNERS')
        except FileNotFoundError:
            issues.append("Code owner reviews required but CODEOWNERS missing")

    # Check team restrictions
    for team in protection.get('restrictions', {}).get('teams', []):
        if not team_exists(team):
            issues.append(f"Protection restricts to non-existent team: {team}")

    return issues
```

**Detection**: Verify external dependencies. Flag configuration that cannot function.

---

## Detection Reporting

**Console output**:

```text
❌ DRIFT: org/api-service (tier: maximum)
  - enforce_admins: disabled
  - required_signatures: disabled
  - status_checks: missing [sast, sbom-generation]
```

**JSON output**:

```json
{"repository": "org/api-service", "tier": "maximum", "drift_detected": true,
 "violations": [{"field": "enforce_admins", "severity": "critical"}]}
```

**Slack alert**:

```yaml
- name: Alert on drift
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: '{"text": "🚨 Drift: ${{ github.repository }} - ${{ steps.drift.outputs.violation_count }} violations"}'
```

---

## Integration with Remediation

### Detection + Immediate Remediation

```yaml
- name: Detect and remediate
  run: |
    if python3 detect-drift.py --repo "${REPO}" --tier "${TIER}"; then
      echo "✅ No drift detected"
    else
      echo "❌ Drift detected - remediating"
      gh api --method PUT "repos/${REPO}/branches/main/protection" --input desired-state.json
    fi
```

### Detection + Manual Approval

```yaml
- name: Create approval issue
  if: failure()
  run: |
    gh issue create \
      --title "Branch protection drift requires approval" \
      --body "$(cat drift-report.json | jq -r '.summary')" \
      --label "security,requires-approval"
```

### Detection + Time-Boxed Remediation

Allow temporary drift with scheduled restoration. See **[Bypass Controls](bypass-controls.md)** for formalized patterns.

---

## Best Practices

**1. Use multiple detection methods**: Webhook for real-time. Scheduled scan for backup. Event-driven for new repositories.

**2. Normalize API responses**: Prevent false positives from null/empty mismatches and format differences.

**3. Log all detections**: Create audit trail even if no remediation taken. Required for compliance.

**4. Implement severity levels**: Critical drift (signatures disabled) requires immediate action. Medium drift (extra status check) can wait.

**5. Test detection logic**: Verify accuracy before organization-wide deployment. Use canary repositories.

**6. Handle API rate limits**: Check remaining requests. Pause if under 100. Use GitHub App authentication (5000 req/hour).

---

## Troubleshooting

**Drift continuously detected despite remediation**: Terraform and GitHub App conflict. Use single source of truth. Disable one enforcement mechanism.

**False positives for identical configurations**: Implement normalization function. Handle null vs empty array. Convert objects to booleans.

**Webhook not triggering detection**: Verify webhook configuration in GitHub App settings. Check delivery history. Confirm webhook secret.

**Detection passes but protection drifted**: Detection logic incomplete. Add field coverage. Test against known drift scenarios.

See **[Troubleshooting](troubleshooting.md)** for additional issues.

---

## Related Patterns

- **[GitHub App Enforcement](github-app-enforcement.md)**: Architecture and enforcement overview
- **[Enforcement Workflows](enforcement-workflows.md)**: Complete workflow implementations
- **[Security Tiers](security-tiers.md)**: Tier configurations for compliance verification
- **[Multi-Repo Management](multi-repo-management.md)**: Organization-wide drift monitoring
- **[Bypass Controls](bypass-controls.md)**: Time-boxed exception handling
- **[Audit Evidence](audit-evidence.md)**: Drift detection as compliance evidence

---

## Next Steps

1. Choose detection approach based on scale (field-level for precision, tier-based for simplicity)
2. Implement detection timing pattern (webhook for real-time, scheduled for backup)
3. Deploy detection script from **[Enforcement Workflows](enforcement-workflows.md)**
4. Configure alerting for drift events
5. Integrate with remediation workflow for automated restoration

---

*Drift was inevitable. Detection was continuous. Remediation was automatic. The gap between desired and actual closed to zero. Compliance became real-time.*
