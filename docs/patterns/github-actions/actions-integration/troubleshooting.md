---
title: Troubleshooting
description: >-
  Debug common issues with Core App token generation and organization access.
---

# Troubleshooting

!!! tip "Debug Workflow First"
    Run the debug workflow at the bottom of this page to quickly identify token scope and permission issues.

## Common Issues

### Token Scope Too Narrow

**Symptom**: `404 Not Found` when accessing org resources

**Solution**: Add `owner` parameter to token generation:

```yaml
owner: your-org  # This parameter is required
```

### Missing Permissions

**Symptom**: `403 Forbidden` errors

**Solution**: Verify Core App has required permissions in app settings

### Team Query Returns Null

**Symptom**: GraphQL returns `"team": null`

**Solution**: Grant "Members" organization permission to Core App

## Debug Workflow

```yaml
name: Debug Core App Integration
on:
  workflow_dispatch:

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Test token
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          echo "Testing Core App token..."

          echo "Checking rate limits:"
          gh api /rate_limit | jq '.resources.core'

          echo "Testing org access:"
          gh api /orgs/your-org | jq '{name, login}'

          echo "Testing team query:"
          gh api graphql -f query='
          {
            organization(login: "your-org") {
              teams(first: 5) {
                nodes {
                  name
                }
              }
            }
          }' | jq '.data.organization.teams'

          echo "All tests passed"
```
