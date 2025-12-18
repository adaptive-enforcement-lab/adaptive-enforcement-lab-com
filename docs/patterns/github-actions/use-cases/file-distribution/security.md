---
title: Security
description: >-
  Secure file distribution with scoped tokens, branch protection, and audit trails. Apply least privilege to automated PR creation and cross-repo operations.
---

# Security Considerations

!!! danger "Principle of Least Privilege"
    Grant minimum permissions. Use short-lived tokens. Require PR review. Never distribute sensitive files.

## Token Scope

```yaml
# Generate org-scoped token
- name: Generate token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: your-org  # Critical for org-wide access
```

## Branch Protection

- Distribution branch should respect branch protection rules
- PRs require approval like any other contribution
- No bypass of security controls

## Audit Trail

- All changes recorded in git history
- PRs provide review opportunity
- Workflow logs show complete execution trace

## Secret Management

| Secret | Storage Level | Access |
| -------- | --------------- | -------- |
| `CORE_APP_ID` | Organization | All repos |
| `CORE_APP_PRIVATE_KEY` | Organization | All repos |
| Workflow token | Job scope | Single run |

## Principle of Least Privilege

Configure Core App with minimum required permissions:

```yaml
# For file distribution, typically need:
permissions:
  contents: write      # Push to branches
  pull_requests: write # Create PRs
  members: read        # Query team membership
```

## Token Lifetime

- Generated tokens are short-lived (1 hour default)
- Tokens are scoped to specific repositories
- No persistent credentials in workflow

## Sensitive File Handling

Avoid distributing sensitive files:

```yaml
- name: Validate files before distribution
  run: |
    # Check for secrets patterns
    if grep -rE "(api_key|password|secret)" source-file.txt; then
      echo "::error::Potential secrets detected in source file"
      exit 1
    fi
```

## PR Review Requirements

Ensure distributed changes require review:

```yaml
- name: Create PR with reviewers
  run: |
    gh pr create \
      --base main \
      --title "chore: automated update" \
      --body "Requires review before merge" \
      --reviewer security-team
```

## Logging Best Practices

```yaml
- name: Audit log
  run: |
    echo "::notice::Distributing to ${{ matrix.repo.name }}"
    echo "::notice::Source commit: ${{ github.sha }}"
    echo "::notice::Actor: ${{ github.actor }}"
```
