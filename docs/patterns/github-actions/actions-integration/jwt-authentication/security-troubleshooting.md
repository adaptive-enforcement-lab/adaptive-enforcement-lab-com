---
title: JWT Security and Troubleshooting
description: >-
  Security best practices, troubleshooting, and performance considerations for JWT authentication workflows.
---

# JWT Security and Troubleshooting

## Token Expiration

## Token Lifecycle and Expiration

```mermaid
sequenceDiagram
    participant W as Workflow
    participant K as Private Key Secret
    participant J as JWT Generator
    participant G as GitHub API

    W->>K: Retrieve private key
    K->>W: Return key
    W->>J: Generate JWT<br/>(app_id + private_key)
    J->>J: Create payload<br/>(iat, exp, iss)
    J->>J: Sign with RS256
    J->>W: Return JWT
    W->>W: Mask token in logs
    W->>G: API request<br/>(Authorization: Bearer JWT)
    G->>G: Validate JWT
    G->>W: App-level response

    Note over J,G: Valid for 10 minutes max
    Note over W,G: Cannot access repositories
```

## Security Best Practices

### 1. Never Expose JWTs

```yaml
# ❌ BAD: Token exposed in logs
- run: echo "JWT: ${{ steps.jwt.outputs.token }}"

# ✅ GOOD: Token masked
- run: |
    echo "::add-mask::${{ steps.jwt.outputs.token }}"
    echo "token=${{ steps.jwt.outputs.token }}" >> $GITHUB_OUTPUT
```

### 2. Minimize JWT Lifetime

```javascript
// ❌ BAD: Maximum 10 minute expiration
const payload = {
  iat: now,
  exp: now + (10 * 60),  // Don't use full 10 minutes if not needed
  iss: appId
};

// ✅ GOOD: Minimal expiration for use case
const payload = {
  iat: now - 60,          // Account for clock skew
  exp: now + (5 * 60),    // 5 minutes is enough for most operations
  iss: appId
};
```

### 3. Secure Private Key Storage

```yaml
# ✅ Store in GitHub Secrets
env:
  GH_APP_PRIVATE_KEY: ${{ secrets.CORE_APP_PRIVATE_KEY }}

# ❌ Never commit private keys to repository
# ❌ Never use hardcoded keys in workflow files
# ❌ Never log private keys (even masked)
```

### 4. Audit JWT Usage

```yaml
- name: Log JWT operation
  run: |
    echo "::notice::Generating JWT for app-level operation"
    echo "Repository: ${{ github.repository }}"
    echo "Workflow: ${{ github.workflow }}"
    echo "Actor: ${{ github.actor }}"
    echo "Operation: List installations"
```

### 5. Use GitHub CLI When Possible

```yaml
# ✅ PREFERRED: Let gh CLI handle JWT generation
- env:
    GH_APP_ID: ${{ secrets.CORE_APP_ID }}
    GH_APP_PRIVATE_KEY: ${{ secrets.CORE_APP_PRIVATE_KEY }}
  run: gh api /app/installations

# ⚠️ ONLY IF NECESSARY: Manual JWT generation
# Use only when gh CLI is unavailable
```

## Troubleshooting

### JWT Validation Errors

```text
Error: Bad credentials (401)
```

**Causes**:

- Incorrect app ID
- Invalid private key format
- Clock skew (iat in future, exp in past)
- Private key doesn't match app

**Solution**:

```yaml
- name: Verify JWT claims
  run: |
    # Decode JWT (without verification) to check claims
    JWT_TOKEN="${{ steps.jwt.outputs.token }}"

    # Extract payload (middle section of JWT)
    PAYLOAD=$(echo $JWT_TOKEN | cut -d'.' -f2)

    # Decode base64
    echo $PAYLOAD | base64 -d | jq .

    # Check:
    # - iss matches your app ID
    # - iat is in past (account for clock skew)
    # - exp is in future
```

### "Resource not accessible by integration"

```text
Error: Resource not accessible by integration (403)
```

**Cause**: Attempting repository operations with JWT.

**Solution**: Use installation token instead.

```yaml
# ❌ Wrong: JWT for repository access
- env:
    GH_APP_ID: ${{ secrets.CORE_APP_ID }}
    GH_APP_PRIVATE_KEY: ${{ secrets.CORE_APP_PRIVATE_KEY }}
  run: gh api /repos/my-org/my-repo

# ✅ Correct: Installation token for repository access
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: my-org
- env:
    GH_TOKEN: ${{ steps.token.outputs.token }}
  run: gh api /repos/my-org/my-repo
```

### Private Key Format Issues

```text
Error: error:0909006C:PEM routines:get_name:no start line
```

**Cause**: Invalid PEM format.

**Solution**:

```bash
# Verify private key format
echo "${{ secrets.CORE_APP_PRIVATE_KEY }}" | head -1
# Should output: -----BEGIN RSA PRIVATE KEY-----

# Key must include newlines
# In GitHub Secrets, paste the entire key including:
# -----BEGIN RSA PRIVATE KEY-----
# [key content]
# -----END RSA PRIVATE KEY-----
```

## Performance Considerations

### JWT Generation Overhead

JWT generation adds ~100-500ms per request.

```yaml
# ❌ Inefficient: Generate JWT for each API call
- run: gh api /app/installations
- run: gh api /app
- run: gh api /app/installations/123

# ✅ Efficient: Batch API calls
- run: |
    gh api /app/installations > installations.json
    gh api /app > app.json
    gh api /app/installations/123 > installation.json
```

### Rate Limits

JWTs share the app-level rate limit: **5,000 requests/hour per app**.

```yaml
- name: Check rate limit
  env:
    GH_APP_ID: ${{ secrets.CORE_APP_ID }}
    GH_APP_PRIVATE_KEY: ${{ secrets.CORE_APP_PRIVATE_KEY }}
  run: |
    gh api /rate_limit --jq '.resources.core | {
      limit: .limit,
      remaining: .remaining,
      reset: .reset
    }'
```

## When NOT to Use JWT

!!! danger "Don't Use JWT For"

    - **Repository operations** - Use installation tokens
    - **Creating PRs or issues** - Use installation tokens
    - **Committing code** - Use installation tokens
    - **User-attributed actions** - Use OAuth
    - **Long-running operations** - 10-minute expiration is too short

## Related Documentation

- [Authentication Decision Guide](../../../secure/github-apps/authentication-decision-guide.md) - Choose the right auth method
- [Token Generation](token-generation.md) - Generate installation tokens
- [Security Best Practices](security-best-practices.md) - Secure token handling
- [Storing Credentials](../../../secure/github-apps/storing-credentials.md) - Secure credential management

## References

- [GitHub Apps Authentication](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app)
- [JWT Specification (RFC 7519)](https://tools.ietf.org/html/rfc7519)
- [GitHub CLI App Authentication](https://cli.github.com/manual/gh_help_environment)
- [App Installation Endpoints](https://docs.github.com/en/rest/apps/installations)
