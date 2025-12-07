---
title: Security Best Practices
description: >-
  Keep Core App tokens secure with proper exposure prevention, minimal
  lifetime, and audit logging.
---

# Security Best Practices

!!! danger "Never Log Tokens"
    Tokens in logs are visible to anyone with workflow access. Use `GH_TOKEN` environment variable, never echo or print tokens.

## Token Exposure Prevention

```yaml
# BAD: Token exposed in logs
- name: Debug token
  run: echo "Token: ${{ steps.app_token.outputs.token }}"

# GOOD: Token used securely
- name: Use token
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api /user
```

## Minimize Token Lifetime

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      # Generate token as late as possible
      - uses: actions/checkout@v4

      - name: Prepare environment
        run: |
          # Setup steps that don't need token
          npm install

      # Generate token only when needed
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Use token immediately
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          gh api /orgs/your-org/repos
```

## Audit Token Usage

```yaml
- name: Log operation
  run: |
    echo "::notice::Starting org-level operation with Core App"
    echo "Repository: ${{ github.repository }}"
    echo "Workflow: ${{ github.workflow }}"
    echo "Actor: ${{ github.actor }}"
```
