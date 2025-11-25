# Troubleshooting

Common issues and solutions for GitHub Core App configuration.

## App Installation Issues

!!! failure "Symptom"

    Cannot install app on organization

!!! check "Checks"

    1. Verify organization owner role
    2. Check organization permissions allow app installation
    3. Review organization security settings

### Solution

```bash
# Verify your role
gh api /orgs/{ORG}/memberships/{USERNAME} --jq '.role'
# Should return: "admin"
```

If not admin, request organization owner access.

## Permission Denied

!!! failure "Symptom"

    Workflows fail with `403 Forbidden`

!!! check "Checks"

    1. Verify app has required permissions in settings
    2. Check app is installed on target repositories
    3. Confirm organization secrets are accessible

### Solution

```yaml
# Debug token permissions
- name: Check token scope
  run: |
    gh api /rate_limit --jq '.resources'
    gh api /installation/repositories --jq '.total_count'
  env:
    GH_TOKEN: ${{ steps.token.outputs.token }}
```

## Team Query Returns Null

!!! failure "Symptom"

    GraphQL query for team repositories returns `"team": null`

!!! check "Checks"

    1. Verify "Members" organization permission is granted
    2. Confirm app is installed at organization level
    3. Check team exists and has repositories

### Solution

```graphql
# Test query
{
  organization(login: "{ORG}") {
    team(slug: "{TEAM}") {
      name
      repositories(first: 5) {
        totalCount
      }
    }
  }
}
```

If `team` is null, add **Members: Read** permission to the app.

## Token Generation Fails

!!! failure "Symptom"

    `actions/create-github-app-token` fails with authentication error

!!! check "Checks"

    1. Verify `CORE_APP_ID` is numeric (not quoted string)
    2. Verify `CORE_APP_PRIVATE_KEY` includes full PEM content
    3. Check private key hasn't expired or been revoked

### Solution

```yaml
- name: Generate token with debug
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
  env:
    # Enable debug logging
    ACTIONS_STEP_DEBUG: true
```

## Rate Limiting

!!! failure "Symptom"

    API calls fail with `403 rate limit exceeded`

!!! check "Checks"

    1. Check current rate limit status
    2. Review workflow for excessive API calls
    3. Consider implementing request batching

### Solution

```bash
# Check rate limits
gh api /rate_limit --jq '.rate'

# Response shows:
# {
#   "limit": 5000,
#   "remaining": 100,
#   "reset": 1234567890
# }
```

## Repository Not Accessible

!!! failure "Symptom"

    App can't access specific repository

!!! check "Checks"

    1. Verify repository is included in app installation
    2. Check repository visibility (private/internal/public)
    3. Confirm app installation scope

### Solution

```bash
# List repositories app can access
gh api /installation/repositories --jq '.repositories[].full_name'
```

If repository missing, update app installation to include it.

## Debug Checklist

- [ ] App ID is correct (check app settings page)
- [ ] Private key is complete (includes BEGIN/END lines)
- [ ] Private key is not expired
- [ ] App is installed on organization
- [ ] App has required permissions
- [ ] Secrets are accessible to workflow
- [ ] Repository is in app's installation scope

## Getting Help

If issues persist:

1. Check [GitHub App documentation](https://docs.github.com/en/apps)
2. Review [GitHub Actions logs](https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows)
3. Enable debug logging: `ACTIONS_STEP_DEBUG: true`

## Next Steps

- [Maintenance and key rotation](maintenance.md)
