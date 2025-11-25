---
title: Performance Optimization
description: >-
  Optimize Core App workflows with token reuse and parallel operations.
---

# Performance Optimization

## Reuse Tokens Across Steps

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token once
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Operation 1
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: gh api /orgs/your-org/repos

      - name: Operation 2
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: gh api /orgs/your-org/teams

      - name: Operation 3
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: gh api /orgs/your-org/members
```

**Advantage**: Single token generation for multiple operations

## Parallel Operations

```yaml
strategy:
  matrix:
    operation: [repos, teams, members]
  max-parallel: 3

steps:
  - name: Generate token
    id: app_token
    uses: actions/create-github-app-token@v2
    with:
      app-id: ${{ secrets.CORE_APP_ID }}
      private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
      owner: your-org

  - name: Execute operation
    env:
      GH_TOKEN: ${{ steps.app_token.outputs.token }}
    run: |
      gh api /orgs/your-org/${{ matrix.operation }}
```
