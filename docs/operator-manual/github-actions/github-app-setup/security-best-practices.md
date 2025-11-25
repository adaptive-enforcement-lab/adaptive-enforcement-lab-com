# Security Best Practices

Essential security guidelines for managing your GitHub Core App.

## Private Key Security

!!! success "Do"

    - Store in GitHub Secrets or secure vault
    - Rotate every 6-12 months
    - Limit access using environment protection

!!! danger "Don't"

    - Never commit to repositories
    - Never log or expose in workflow output
    - Never share via unsecured channels

## Permission Principles

1. **Least Privilege** - Grant minimum permissions required
2. **Regular Review** - Audit permissions quarterly
3. **Scope Validation** - Verify token scope before operations
4. **Access Control** - Use environment protection rules

## Token Lifecycle

GitHub App tokens generated in workflows:

| Aspect | Details |
|--------|---------|
| **Lifetime** | 1 hour (automatic expiration) |
| **Scope** | Exact permissions granted to app |
| **Renewal** | Regenerated per workflow run |
| **Revocation** | Revoke app installation to invalidate all tokens |

## Audit and Monitoring

Monitor Core App usage:

### Audit Log

Review app actions in organization audit log:

- Filter by `actor:app/CORE_APP_NAME`
- Review API calls and repository access
- Track permission usage patterns

### Webhook Events

Optional: Track app activity via webhooks:

- `installation` - App installation changes
- `installation_repositories` - Repository access changes
- `github_app_authorization` - User authorizations

### Rate Limits

Monitor API usage via response headers:

```text
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 4999
X-RateLimit-Reset: 1234567890
```

### Permission Changes

Alert on app permission modifications:

- Review audit log for `integration.update`
- Set up alerts for permission scope changes
- Document all permission modifications

## Workflow Security

### Secret Masking

Ensure secrets are never exposed:

```yaml
- name: Generate token
  id: token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}

# Token is automatically masked in logs
- name: Use token
  run: echo "Token length: ${#TOKEN}"
  env:
    TOKEN: ${{ steps.token.outputs.token }}
```

### Environment Protection

Use protected environments for sensitive operations:

```yaml
jobs:
  deploy:
    environment:
      name: production
      url: https://example.com
    steps:
      - uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
```

## Security Checklist

- [ ] Private key stored in GitHub Secrets (not in code)
- [ ] Organization secrets used (not repository secrets)
- [ ] Minimum required permissions granted
- [ ] Environment protection enabled for sensitive workflows
- [ ] Audit log monitoring configured
- [ ] Key rotation schedule documented
- [ ] Access to secrets limited to required personnel

## Next Steps

- [Installation scopes](installation-scopes.md)
- [Maintenance and key rotation](maintenance.md)
