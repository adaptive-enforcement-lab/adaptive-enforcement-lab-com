---
title: GitHub Apps for Machine Authentication
description: >-
  Replace Personal Access Tokens with GitHub Apps for automation.
  Scoped permissions, lifecycle independence, and full audit trails.
---

# GitHub Apps for Machine Authentication

Personal Access Tokens (PATs) fail audits. They're tied to individuals who leave. Rotation is manual. Scope is too broad.

GitHub Apps solve all three problems.

---

## The PAT Problem

```yaml
# FAILS AUDIT
- uses: actions/create-release@v1
  with:
    token: ${{ secrets.MARK_GITHUB_TOKEN }}
```

Auditor questions:

- What happens when Mark leaves the company?
- Who can rotate Mark's token?
- What else can this token do besides create releases?
- How do we audit its use across repositories?

No good answers. Finding noted.

---

## GitHub App Solution

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

```yaml
# PASSES AUDIT
- name: Generate App Token
  id: app-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.RELEASE_APP_ID }}
    private-key: ${{ secrets.RELEASE_APP_PRIVATE_KEY }}
    owner: adaptive-enforcement-lab

- uses: actions/create-release@v1
  with:
    token: ${{ steps.app-token.outputs.token }}
```

This answers every question:

- Token lifecycle independent of employees
- Scoped to specific permissions (read/write releases only)
- Rotation via private key management
- Full audit trail of app actions

---

## Creating a GitHub App

See [GitHub App Setup Guide](../../../operator-manual/github-actions/github-app-setup/index.md) for complete setup.

Quick steps:

1. Navigate to Organization Settings → GitHub Apps → New GitHub App
2. Set app name (e.g., "Release Automation")
3. Uncheck webhook (not needed for automation)
4. Set permissions (e.g., `contents: write` for releases)
5. Install app on organization
6. Generate private key

---

## Permission Scoping

GitHub Apps use granular permissions. Only grant what's needed.

### Release Automation

```yaml
# App permissions
permissions:
  contents: write  # Create releases and tags
```

### PR Automation

```yaml
# App permissions
permissions:
  pull_requests: write  # Create and update PRs
  contents: read        # Read repository content
```

### Issue Management

```yaml
# App permissions
permissions:
  issues: write  # Create, update, close issues
```

See [Common Permissions](../../../operator-manual/github-actions/github-app-setup/common-permissions.md) for full matrix.

---

## Token Generation in Workflows

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.PRIVATE_KEY }}
          owner: my-org

      - name: Use token
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          gh release create v1.0.0 --notes "Release notes"
```

Tokens are short-lived (1 hour). Automatically revoked after use.

---

## Credential Storage

Store in GitHub repository secrets (Settings → Secrets and variables → Actions):

- `APP_ID` - GitHub App ID (numeric)
- `PRIVATE_KEY` - Private key (PEM format)

```bash
# Get App ID from app settings page
# Generate private key via "Generate a private key" button

# Add to repository secrets
gh secret set APP_ID --body "123456"
gh secret set PRIVATE_KEY < private-key.pem
```

Private keys are encrypted at rest. Only accessible to workflows.

---

## Organization-Wide vs Repository-Specific

### Organization Installation

```yaml
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.PRIVATE_KEY }}
    owner: my-org  # Works across all repos in org
```

### Repository-Specific

```yaml
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.PRIVATE_KEY }}
    owner: my-org
    repositories: repo1,repo2  # Limited scope
```

Principle of least privilege: Limit scope to specific repositories when possible.

---

## Audit Trail

GitHub tracks all app actions:

```bash
# View app activity
gh api /orgs/my-org/audit-log \
  --jq '.[] | select(.action | startswith("integration")) |
    {action, actor, created_at}'
```

Shows:

- Which app performed the action
- What action was taken
- When it happened
- Which resources were affected

Auditors can verify app usage history.

---

## Token Rotation

PAT rotation requires manual update in secrets. App tokens rotate automatically.

### Automatic Rotation

GitHub Apps generate fresh tokens per workflow run. No manual rotation needed.

### Private Key Rotation

When private key is compromised:

1. Generate new private key in app settings
2. Update `PRIVATE_KEY` secret
3. Revoke old key
4. Audit app activity during key validity period

Private key rotation doesn't break existing workflows. Update secret, done.

---

## Cross-Repository Operations

GitHub Apps can operate across repositories:

```yaml
- name: Generate token for multi-repo
  id: app-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.PRIVATE_KEY }}
    owner: my-org
    repositories: repo1,repo2,repo3

- name: Create PRs across repos
  env:
    GH_TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    for repo in repo1 repo2 repo3; do
      gh pr create --repo my-org/$repo \
        --title "Update dependencies" \
        --body "Automated update"
    done
```

See [File Distribution](../../../operator-manual/github-actions/use-cases/file-distribution/index.md) for full pattern.

---
