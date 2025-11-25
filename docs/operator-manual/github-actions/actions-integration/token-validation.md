---
title: Token Validation
description: >-
  Verify token scope and permissions for organization and team access.
---

# Token Scope Validation

## Verify Organization Access

Test if your token has organization-level permissions:

```yaml
- name: Validate org access
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    # Should succeed if owner parameter was specified
    gh api /orgs/your-org/members | jq 'length'
```

## Verify Team Query Access

Test if your token can query team repositories:

```yaml
- name: Validate team access
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    RESULT=$(gh api graphql -f query='
    {
      organization(login: "your-org") {
        team(slug: "engineering") {
          name
        }
      }
    }' --jq '.data.organization.team')

    if [ "$RESULT" = "null" ]; then
      echo "Team query failed - check Members permission"
      exit 1
    fi

    echo "Team query successful"
```
