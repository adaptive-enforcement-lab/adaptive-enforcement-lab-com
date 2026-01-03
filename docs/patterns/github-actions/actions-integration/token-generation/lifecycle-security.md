---
title: Security and Troubleshooting
description: >-
  Security best practices, troubleshooting common issues, and performance optimization for GitHub App installation tokens.
---

# Security and Troubleshooting

## Security Best Practices

### 1. Token Masking

Tokens are automatically masked in logs, but be careful with debugging.

```yaml
# ✅ GOOD: Token automatically masked
- name: Generate token
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}

# ❌ BAD: Don't output tokens for debugging
- run: echo "Token: ${{ steps.app_token.outputs.token }}"
```

### 2. Scope Minimization

Use the narrowest scope possible.

```yaml
# ✅ GOOD: Explicit repository list
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    repositories: |
      repo1
      repo2

# ⚠️ USE WITH CAUTION: Org-wide access
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: your-org  # Access to all installed repos
```

### 3. Secure Credential Storage

```yaml
# ✅ GOOD: Use organization or repository secrets
with:
  app-id: ${{ secrets.CORE_APP_ID }}
  private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}

# ❌ BAD: Never hardcode credentials
with:
  app-id: "123456"
  private-key: "-----BEGIN RSA PRIVATE KEY-----..."
```

### 4. Audit Logging

Log token generation for audit trails.

```yaml
- name: Generate token (audited)
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: adaptive-enforcement-lab

- name: Log token generation
  run: |
    echo "::notice::Generated installation token for adaptive-enforcement-lab"
    echo "Workflow: ${{ github.workflow }}"
    echo "Actor: ${{ github.actor }}"
    echo "Repository: ${{ github.repository }}"
```

### 5. Permission Boundaries

Configure minimal app permissions.

```yaml
# In your GitHub App settings, grant only necessary permissions:
# - Repository permissions:
#   - Contents: Read (for reading code)
#   - Issues: Write (for creating issues)
#   - Pull Requests: Write (for creating PRs)
# - Organization permissions:
#   - Members: Read (for listing org members)
```

## Troubleshooting

### Token Generation Fails

```text
Error: Failed to create installation access token
```

**Causes**:

- App not installed on target repository/organization
- Invalid app ID or private key
- App permissions insufficient

**Solution**:

```yaml
- name: Verify app installation
  env:
    GH_APP_ID: ${{ secrets.CORE_APP_ID }}
    GH_APP_PRIVATE_KEY: ${{ secrets.CORE_APP_PRIVATE_KEY }}
  run: |
    # List installations (requires JWT)
    gh api /app/installations --jq '.[] | {id: .id, account: .account.login}'

    # Verify installation exists for target organization
```

### Repository Not Accessible

```text
Error: Resource not accessible by integration (403)
```

**Causes**:

- Repository not in `repositories` parameter
- App not installed on repository
- Insufficient app permissions

**Solution**:

```yaml
# Check repository list
- name: Debug repository access
  run: |
    echo "Attempting to access: ${{ github.repository }}"
    echo "Token scoped to: ${{ matrix.repository }}"

# Ensure repository is in scope
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    repositories: |
      ${{ github.event.repository.name }}  # Add current repo
      other-repo
```

### Token Expired Mid-Workflow

```text
Error: Bad credentials (401)
```

**Cause**: Token expired after 1 hour.

**Solution**:

```yaml
# Regenerate token for long-running workflows
- name: Long processing step
  run: |
    # ... work that takes >30 minutes ...

- name: Refresh token
  id: refreshed_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: adaptive-enforcement-lab

- name: Continue with fresh token
  env:
    GH_TOKEN: ${{ steps.refreshed_token.outputs.token }}
  run: |
    # ... more work ...
```

### Private Key Format Issues

```text
Error: error:0909006C:PEM routines:get_name:no start line
```

**Cause**: Invalid PEM format in secret.

**Solution**:

```bash
# Verify private key format in GitHub Secrets
# Key must include newlines and markers:
-----BEGIN RSA PRIVATE KEY-----
[key content with newlines]
-----END RSA PRIVATE KEY-----

# Test private key locally
openssl rsa -in private-key.pem -check
```

## Performance Considerations

### Token Generation Overhead

Each token generation adds ~500ms-1s to workflow execution.

```yaml
# ❌ Inefficient: Multiple token generations
- id: token1
  uses: actions/create-github-app-token@v2
  ...
- run: gh api /repos/org/repo1
  env:
    GH_TOKEN: ${{ steps.token1.outputs.token }}

- id: token2
  uses: actions/create-github-app-token@v2
  ...
- run: gh api /repos/org/repo2
  env:
    GH_TOKEN: ${{ steps.token2.outputs.token }}

# ✅ Efficient: Reuse token across steps
- id: app_token
  uses: actions/create-github-app-token@v2
  with:
    owner: org

- run: |
    gh api /repos/org/repo1
    gh api /repos/org/repo2
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
```

### Rate Limits

Installation tokens share the installation's rate limit: **5,000 requests/hour per installation**.

```yaml
- name: Check rate limit
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api /rate_limit --jq '.resources.core | {
      limit: .limit,
      remaining: .remaining,
      reset_at: (.reset | strftime("%Y-%m-%d %H:%M:%S"))
    }'
```

### Caching for Repeated Operations

```yaml
- name: Generate token (cache-friendly)
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: adaptive-enforcement-lab

- name: Cache token for reuse
  run: |
    # Store token in environment for all subsequent steps
    echo "GH_TOKEN=${{ steps.app_token.outputs.token }}" >> $GITHUB_ENV

- name: Operation 1
  run: gh repo list adaptive-enforcement-lab

- name: Operation 2
  run: gh issue list --repo adaptive-enforcement-lab/repo1

- name: Operation 3
  run: gh pr list --repo adaptive-enforcement-lab/repo2

# All operations reuse the same token from environment
```

## Related Documentation

- [Authentication Decision Guide](../../../../secure/github-apps/authentication-decision-guide.md) - Choose the right auth method
- [Token Refresh Patterns](../token-lifecycle/refresh-patterns.md) - Token lifecycle and expiration handling
- [JWT Authentication](../jwt-authentication/index.md) - App-level authentication for installation discovery
- [OAuth User Authentication](../oauth-authentication/index.md) - User-context operations
- [Storing Credentials](../../../../secure/github-apps/storing-credentials/index.md) - Secret management patterns

## References

- [actions/create-github-app-token](https://github.com/actions/create-github-app-token) - Official action documentation
- [GitHub Apps Authentication](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app)
- [Installation Access Tokens](https://docs.github.com/en/rest/apps/installations#create-an-installation-access-token-for-an-app)
