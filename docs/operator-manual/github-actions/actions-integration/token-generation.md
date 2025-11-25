---
title: Token Generation
description: >-
  Generate short-lived tokens from GitHub Core App credentials using
  the official actions/create-github-app-token action.
---

# Token Generation Action

GitHub provides the official `actions/create-github-app-token` action for
generating short-lived tokens from your Core App credentials.

## Basic Usage

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - name: Generate Core App Token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
```

**Output**: The action generates a token accessible via
`${{ steps.app_token.outputs.token }}`

## Organization-Scoped Tokens

To generate tokens with organization-wide access:

```yaml
- name: Generate Org-Scoped Token
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: your-org  # Critical: enables org-scoped access
```

**Critical Parameter**:

- **`owner`** - MUST be specified for organization-level operations
- Without `owner`, tokens are scoped only to the current repository
- Value must match your GitHub organization name exactly

## Repository-Scoped Tokens

For operations limited to specific repositories:

```yaml
- name: Generate Repo-Scoped Token
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    repositories: |
      repo1
      repo2
      repo3
```

**Use case**: Operating on specific repositories without org-wide access
