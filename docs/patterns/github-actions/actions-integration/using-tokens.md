---
title: Using Tokens
description: >-
  Integrate Core App tokens with GitHub CLI, Git operations, checkout action,
  and GitHub APIs.
---

# Using Generated Tokens

Once you've generated a token, here's how to use it with various tools.

!!! tip "GH_TOKEN Environment Variable"
    Set `GH_TOKEN` to automatically authenticate all `gh` CLI commands. No manual configuration needed.

## With GitHub CLI (gh)

The most common integration is with the GitHub CLI:

```yaml
- name: Use token with gh CLI
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api /repos/${{ github.repository }}/issues
```

**Environment Variable**: `GH_TOKEN` is automatically recognized by `gh`

## With Git Operations

For git clone, push, and other operations:

```yaml
- name: Clone repository with Core App
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh repo clone org/repository target-dir

- name: Configure git authentication
  working-directory: target-dir
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    git config --local credential.helper \
      '!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f'
```

## With actions/checkout

Use the token with the checkout action:

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    token: ${{ steps.app_token.outputs.token }}
    repository: org/target-repo
```

**Advantage**: Subsequent git operations use the Core App token

## With GraphQL API

Query organization data using GraphQL:

```yaml
- name: Query organization
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api graphql -f query='
    {
      organization(login: "your-org") {
        repositories(first: 10) {
          nodes {
            name
            url
          }
        }
      }
    }'
```

## With REST API

Use the token with REST API calls:

```yaml
- name: Call REST API
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api /orgs/your-org/repos --jq '.[].name'
```
