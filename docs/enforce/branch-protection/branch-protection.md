---
title: Branch Protection Enforcement
description: >-
  GitHub branch protection rules as policy enforcement. Required reviews, status checks,
  and admin enforcement patterns that survive audit scrutiny.
tags:
  - github
  - security
  - compliance
  - automation
  - developers
  - operators
  - policy-enforcement
---

# Branch Protection Rules Reference

Detailed configuration reference for GitHub branch protection rules.

!!! info "Part of Branch Protection Enforcement Patterns"
    This page provides the detailed rules reference. For overview and architecture, see **[Branch Protection Enforcement Patterns](index.md)**. For pre-configured templates, see **[Security Tiers](security-tiers.md)**.

!!! warning "Security Foundation"
    These controls form the baseline security posture. All controls must be implemented for audit compliance.

GitHub enforces the rules. No bypasses. Full audit trail.

## The Enforcement Problem

**Documentation approach**:

> "All code must be reviewed by at least one other engineer before merging to main."

Provable? No. A developer could merge their own PR. The policy says they shouldn't, but nothing stops them.

**Enforcement approach**:

GitHub branch protection makes it impossible to merge without approval.

## Basic Configuration

!!! tip "Pre-Configured Templates Available"
    Instead of manual configuration, use tier templates: **[Security Tiers](security-tiers.md)** provides Standard, Enhanced, and Maximum tier configurations.

```yaml
# Enforced via GitHub branch protection rules
branch_protection:
  required_pull_request_reviews:
    required_approving_review_count: 1
    dismiss_stale_reviews: true
    require_code_owner_reviews: true

  required_status_checks:
    strict: true
    contexts:
      - "ci/tests"
      - "security/scan"

  enforce_admins: true
  required_linear_history: true
```

Configuration via GitHub UI or API. Once enabled, the rules are immutable until explicitly changed.

## Required Reviews

### Minimum Approvals

```yaml
required_pull_request_reviews:
  required_approving_review_count: 1
```

Cannot merge until at least one other person approves.

### Dismiss Stale Reviews

```yaml
dismiss_stale_reviews: true
```

New commits invalidate previous approvals. Forces re-review after changes.

### Code Owner Reviews

```yaml
require_code_owner_reviews: true
```

Requires approval from designated code owners. Defined in `.github/CODEOWNERS`:

```text
# CODEOWNERS
/infrastructure/**  @platform-team
/security/**        @security-team
*.yaml              @devops-team
```

Ownership-based review ensures domain experts see changes.

## Required Status Checks

### Strict Mode

```yaml
required_status_checks:
  strict: true
```

Branch must be up-to-date with base branch. Prevents integration issues.

### Required Checks

```yaml
contexts:
  - "ci/tests"
  - "security/scan"
  - "lint/code-quality"
```

All listed checks must pass before merge. Failed check blocks the PR.

## Administrator Enforcement

```yaml
enforce_admins: true
```

**Critical**: Applies rules to administrators too.

Without this, org admins can bypass reviews and status checks. Auditors will flag this as a control gap.

## Additional Protections

### Linear History

```yaml
required_linear_history: true
```

Prevents merge commits. Enforces rebase or squash workflows.

### Force Push Protection

```yaml
allow_force_pushes: false
```

Blocks force pushes to protected branches. Preserves git history integrity.

### Deletion Protection

```yaml
allow_deletions: false
```

Prevents accidental or malicious branch deletion.

## Configuration via API

!!! tip "Infrastructure as Code"
    For production deployments, use **[Terraform Modules](terraform-modules.md)** or **[OpenTofu Modules](opentofu-modules.md)** instead of manual API calls.

Terraform and manual UI configuration don't scale. Use GitHub API:

```bash
# Get current protection
gh api repos/org/repo/branches/main/protection

# Set protection
gh api \
  --method PUT \
  repos/org/repo/branches/main/protection \
  --input protection-config.json
```

Example `protection-config.json`:

```json
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["ci/tests", "security/scan"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
```

## Audit Trail

GitHub provides automatic audit trail:

```bash
# Get PR review history for March 2025
gh api \
  'repos/org/repo/pulls?state=closed&base=main' \
  --jq '.[] | select(.merged_at | startswith("2025-03")) |
    {number, title, reviews: .requested_reviewers | length,
     merged: .merged_at}'
```

Output proves:

- PR numbers
- Review counts
- Merge timestamps
- Reviewer identities

Auditors can verify controls were active during any historical period.

## Exception Handling

!!! info "Formalized Bypass Controls"
    For production systems, implement formal bypass procedures: **[Bypass Controls](bypass-controls.md)** and **[Emergency Access](emergency-access.md)** provide approval workflows and audit patterns.

### Emergency Bypass

Sometimes you need to bypass protection (production outage, security hotfix).

**Pattern**: Temporary disable via API, re-enable immediately after merge.

```bash
# Disable protection
gh api --method DELETE repos/org/repo/branches/main/protection

# Merge emergency fix
git push origin hotfix

# Re-enable protection
gh api --method PUT repos/org/repo/branches/main/protection \
  --input protection-config.json
```

**Critical**: Log every exception. Include:

- Timestamp
- Who requested bypass
- Reason (ticket reference)
- Duration
- Post-merge review confirmation

Auditors accept documented exceptions. They don't accept casual bypasses.

## Multi-Repository Enforcement

!!! tip "Advanced Patterns Available"
    For comprehensive organization-wide enforcement, see **[Multi-Repo Management](multi-repo-management.md)** and **[GitHub App Enforcement](github-app-enforcement.md)**.

Applying protection to 100+ repositories manually doesn't scale.

### GitHub Actions Workflow

```yaml
name: Enforce Branch Protection

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  workflow_dispatch:

jobs:
  enforce:
    runs-on: ubuntu-latest
    steps:
      - name: Get repositories
        id: repos
        run: |
          gh api orgs/my-org/repos --paginate --jq '.[].name' > repos.txt

      - name: Apply protection
        run: |
          while read repo; do
            gh api --method PUT \
              repos/my-org/$repo/branches/main/protection \
              --input protection-config.json || echo "Failed: $repo"
          done < repos.txt
```

Weekly enforcement ensures new repositories inherit protection.

## Verification Script

!!! info "Enhanced Verification"
    For comprehensive audit preparation and continuous monitoring, see **[Verification Scripts](verification-scripts.md)**.

Audit preparation: Verify protection across all repositories.

```bash
#!/bin/bash
# verify-branch-protection.sh

REPOS=$(gh api orgs/my-org/repos --paginate --jq '.[].name')

for repo in $REPOS; do
  PROTECTION=$(gh api repos/my-org/$repo/branches/main/protection 2>/dev/null)

  if [ -z "$PROTECTION" ]; then
    echo "❌ $repo: NO PROTECTION"
  else
    ENFORCE_ADMINS=$(echo "$PROTECTION" | jq -r '.enforce_admins.enabled')
    REQ_REVIEWS=$(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count')

    if [ "$ENFORCE_ADMINS" = "true" ] && [ "$REQ_REVIEWS" -ge "1" ]; then
      echo "✅ $repo: Protected"
    else
      echo "⚠️  $repo: Weak protection"
    fi
  fi
done
```

Output shows compliance status per repository.

## Common Pitfalls

### Pitfall 1: Forgetting enforce_admins

Administrators can bypass all rules. Auditors will test this.

### Pitfall 2: No Status Check Requirement

Reviews without CI checks allow broken code to merge.

### Pitfall 3: Undocumented Exceptions

Emergency bypasses are acceptable. Undocumented bypasses are findings.

### Pitfall 4: Inconsistent Enforcement

Protection on `main` but not `production`. Apply to all release branches.

## Integration with Status Checks

Branch protection works best with required status checks.

See [Required Status Checks](../status-checks/index.md) for full CI/CD integration.

## Related Patterns

**Branch Protection**: [Overview](index.md) · [Security Tiers](security-tiers.md) · [Multi-Repo](multi-repo-management.md) · [GitHub App Enforcement](github-app-enforcement.md) · [Drift Detection](drift-detection.md) · [Bypass Controls](bypass-controls.md) · [Emergency Access](emergency-access.md) ·
[Verification Scripts](verification-scripts.md)

**Infrastructure as Code**: [Terraform Modules](terraform-modules.md) ·
[OpenTofu Modules](opentofu-modules.md)

**Audit & Compliance**: [Audit Evidence](audit-evidence.md) ·
[Compliance Reporting](compliance-reporting.md)

**Related Controls**: [Commit Signing](../commit-signing/commit-signing.md) ·
[Required Status Checks](../status-checks/index.md) · [GitHub Apps](../../secure/github-apps/index.md)

---

*Policies became impossible to bypass. Auditors queried the API. Evidence was irrefutable. Controls passed.*
