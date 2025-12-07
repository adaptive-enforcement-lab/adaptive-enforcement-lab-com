---
title: GitHub Apps - Patterns and Best Practices
description: >-
  PAT vs GitHub App comparison, common automation patterns,
  and security best practices for GitHub Apps.
---

# GitHub Apps - Patterns and Best Practices

## Comparison: PATs vs GitHub Apps

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

| Aspect | Personal Access Token | GitHub App |
| -------- | ---------------------- | ------------ |
| Lifecycle | Tied to individual | Independent |
| Permissions | Broad (all repos) | Scoped (specific repos/permissions) |
| Rotation | Manual | Automatic (per run) |
| Audit trail | User actions | App actions |
| Token lifetime | Long-lived (months/years) | Short-lived (1 hour) |
| Revocation | Manual | Automatic |
| Compliance | ❌ Fails audits | ✅ Passes audits |

---

## Common Patterns

### Pattern 1: Release Automation

```yaml
permissions:
  contents: write

- name: Create release
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    gh release create ${{ github.ref_name }} \
      --generate-notes
```

### Pattern 2: PR Creation

```yaml
permissions:
  pull_requests: write
  contents: read

- name: Create PR
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    gh pr create \
      --title "Automated update" \
      --body "$(cat PR_BODY.md)"
```

### Pattern 3: Issue Management

```yaml
permissions:
  issues: write

- name: Close stale issues
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    gh issue list --state open --label stale --json number \
      --jq '.[].number' | xargs -I {} gh issue close {}
```

---

## Security Best Practices

### Principle 1: Minimal Scope

Only grant permissions the app needs. Don't use `admin` when `write` suffices.

### Principle 2: Repository Limitation

Limit app installation to specific repositories, not entire organization (unless needed).

### Principle 3: Short-Lived Tokens

Use generated tokens immediately. Don't store them.

### Principle 4: Private Key Security

Treat private keys like passwords:

- Never commit to git
- Rotate if exposed
- Store in GitHub secrets (encrypted)

### Principle 5: Audit Regularly

Review app activity monthly:

```bash
gh api /orgs/my-org/audit-log \
  --jq '.[] | select(.action | startswith("integration"))'
```

Look for unexpected actions.

---
