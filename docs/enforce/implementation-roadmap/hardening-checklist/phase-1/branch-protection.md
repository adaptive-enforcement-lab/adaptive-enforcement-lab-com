---
description: >-
  Branch protection rules for SDLC hardening. Required reviews, status checks, admin enforcement, commit signatures, history protection, and organization-wide automation to prevent unauthorized merges.
tags:
  - branch-protection
  - code-review
  - github
  - commit-signing
  - enforcement
---

# Phase 1: Branch Protection Rules

Make it impossible to merge without meeting security criteria.

---

## Required Review Configuration

### Pull Request Reviews

- [ ] **Enable required pull request reviews**

  ```json
  {
    "required_pull_request_reviews": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "require_last_push_approval": true
    }
  }

  ```

  **How to validate**:

  ```bash
  gh api repos/org/repo/branches/main/protection | \
    jq '.required_pull_request_reviews'
  ```

  **Why it matters**: At least one other set of eyes sees every change. Dismissing stale reviews forces re-review after new commits. Code owner review brings domain expertise.

!!! warning "Stale Review Dismissal"
    If you don't dismiss stale reviews, a developer can get approval, push malicious code, and merge without re-review. Enable this setting immediately.

---

## Required Status Checks

### CI Gates

- [ ] **Require all CI status checks to pass**

  ```json
  {
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "ci/tests",
        "ci/lint",
        "ci/security-scan",
        "ci/sbom-generation"
      ]
    }
  }

  ```

  **How to validate**:

  ```bash
  # Try to merge with failing check (should be blocked)
  gh pr merge PR_NUMBER --squash 2>&1 | grep -i "status check"
  ```

  **Why it matters**: Broken code, untested code, and code without security scans never merge. CI is a gate, not a log.

---

## Administrator Enforcement

### Apply to Admins

- [ ] **Apply branch protection to administrators**

  ```json
  {
    "enforce_admins": true
  }

  ```

  **How to validate**:

  ```bash
  gh api repos/org/repo/branches/main/protection | \
    jq '.enforce_admins.enabled'
  # Should return: true
  ```

  **Why it matters**: If admins can bypass, the policy is worthless. Auditors will test this first.

!!! failure "Common Mistake"
    Setting `enforce_admins: false` because "we might need emergency access". Wrong. Keep it enabled. If emergency happens, document the bypass, use it, then re-enable immediately.

---

## Commit Signature Requirements

### Signed Commits

- [ ] **Require signed commits on protected branches**

  ```json
  {
    "required_signatures": true
  }

  ```

  **How to validate**:

  ```bash
  # Check that last 10 commits are signed
  git log -10 --pretty=format:'%G? %h %s' | grep -v '^G '
  # Should return empty (all signed)
  ```

  **Why it matters**: Proves authorship cryptographically. Prevents account compromise without a signature key.

---

## History Protection

### Force Push Prevention

- [ ] **Prevent force pushes and deletions**

  ```json
  {
    "allow_force_pushes": false,
    "allow_deletions": false,
    "required_linear_history": true
  }

  ```

  **How to validate**:

  ```bash
  gh api repos/org/repo/branches/main/protection | \
    jq '{force_pushes: .allow_force_pushes, deletions: .allow_deletions, linear: .required_linear_history}'
  ```

  **Why it matters**: Git history is the audit trail. Force pushes and deletions can erase evidence. Linear history prevents merge commits that hide context.

---

## Organization-Wide Enforcement

### Automated Rollout

- [ ] **Apply branch protection to all repositories**

  ```bash
  #!/bin/bash
  # scripts/enforce-branch-protection.sh

  PROTECTION_CONFIG='{
    "required_pull_request_reviews": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true
    },
    "required_status_checks": {
      "strict": true,
      "contexts": ["ci/tests", "ci/lint", "ci/security-scan"]
    },
    "enforce_admins": true,
    "required_linear_history": true,
    "allow_force_pushes": false,
    "allow_deletions": false
  }'

  gh repo list org --limit 1000 --json name --jq '.[].name' | while read repo; do
    echo "Enforcing: $repo"
    gh api --method PUT repos/org/$repo/branches/main/protection \
      --input <(echo "$PROTECTION_CONFIG") || echo "Failed: $repo"
  done

  ```

  **How to validate**:

  ```bash
  # Count protected repos
  gh repo list org --limit 1000 --json name --jq '.[].name' | while read repo; do
    gh api repos/org/$repo/branches/main/protection >/dev/null 2>&1 && echo "✅"
  done | grep "✅" | wc -l
  ```

  **Why it matters**: Manual enforcement doesn't scale. Automation applies rules consistently across all repositories.

!!! success "Scale Pattern"
    Run this script weekly via GitHub Actions. New repositories automatically get branch protection. Existing repos get updated configurations. Zero manual intervention.

---

## Common Issues and Solutions

**Issue**: Branch protection breaks automated releases

**Solution**: Use a service account with exemption, not a personal account:

```json
{
  "restrictions": {
    "users": [],
    "teams": ["release-automation-service-account"]
  }
}
```

---

## Related Patterns

- **[Pre-commit Hooks](pre-commit-hooks.md)** - Local enforcement
- **[Phase 1 Overview →](index.md)** - Foundation phase summary
- **[Phase 2: Automation →](../phase-2/index.md)** - CI/CD gates

---

*Branch protection enforced. Admins cannot bypass. Force pushes blocked. History is immutable.*
