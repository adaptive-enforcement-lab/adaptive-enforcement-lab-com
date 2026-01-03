---
title: Token Lifecycle Best Practices
description: >-
  Best practices, patterns, and troubleshooting for token lifecycle management in GitHub Actions workflows.
---

## Best Practices

### 1. Proactive Refresh

```yaml
# ✅ GOOD: Refresh at 55 minutes
- name: Check token age and refresh proactively
  run: |
    TOKEN_AGE_SECONDS=$(($(date +%s) - TOKEN_CREATED))
    if [ $TOKEN_AGE_SECONDS -gt 3300 ]; then
      # Refresh token
    fi

# ❌ BAD: Wait for 401 error
- run: |
    # API call fails at 60 minutes
    gh api user  # Error: Bad credentials
```

### 2. Minimize Token Generations

```yaml
# ✅ GOOD: Generate once, share across jobs
jobs:
  setup:
    outputs:
      token: ${{ steps.token.outputs.token }}
  job-1:
    needs: setup
    env:
      GH_TOKEN: ${{ needs.setup.outputs.token }}
  job-2:
    needs: setup
    env:
      GH_TOKEN: ${{ needs.setup.outputs.token }}

# ❌ BAD: Generate token in every job
jobs:
  job-1:
    steps:
      - uses: actions/create-github-app-token@v2
  job-2:
    steps:
      - uses: actions/create-github-app-token@v2
```

### 3. Monitor Rate Limits

```yaml
# ✅ GOOD: Check rate limits periodically
- run: |
    REMAINING=$(gh api /rate_limit --jq '.resources.core.remaining')
    if [ $REMAINING -lt 100 ]; then
      echo "::warning::Rate limit low: $REMAINING"
    fi

# ❌ BAD: No rate limit awareness
- run: |
    for i in {1..10000}; do
      gh api user  # Will hit rate limit
    done
```

### 4. Graceful Degradation

```yaml
# ✅ GOOD: Implement backoff and retry
- run: |
    if ! gh api user; then
      echo "::notice::API call failed, waiting 60s"
      sleep 60
      gh api user  # Retry
    fi

# ❌ BAD: No error handling
- run: gh api user  # Fails workflow on error
```

## Troubleshooting

### Token Expired During Workflow

```text
Error: Bad credentials (401)
```

**Solution**:

```yaml
- name: Refresh expired token
  if: failure()
  id: refresh
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: adaptive-enforcement-lab

- name: Retry operation
  if: failure()
  env:
    GH_TOKEN: ${{ steps.refresh.outputs.token }}
  run: |
    # Retry failed operation
    gh api user
```

### Rate Limit Exceeded

```text
Error: API rate limit exceeded (403)
```

**Solution**:

```yaml
- name: Wait for rate limit reset
  run: |
    RESET_TIME=$(gh api /rate_limit --jq '.resources.core.reset')
    CURRENT_TIME=$(date +%s)
    WAIT_TIME=$((RESET_TIME - CURRENT_TIME))

    if [ $WAIT_TIME -gt 0 ]; then
      echo "::notice::Waiting $((WAIT_TIME / 60)) minutes for rate limit reset"
      sleep $WAIT_TIME
    fi
```

### Token Cache Stale

**Problem**: Cached token expired before dependent jobs started.

**Solution**:

```yaml
# Add token age check before using cached token
- name: Validate cached token
  id: validate
  env:
    GH_TOKEN: ${{ needs.token-provider.outputs.token }}
  run: |
    if gh api user > /dev/null 2>&1; then
      echo "valid=true" >> $GITHUB_OUTPUT
    else
      echo "valid=false" >> $GITHUB_OUTPUT
    fi

- name: Generate fresh token if cache invalid
  if: steps.validate.outputs.valid != 'true'
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
```

## Related Documentation

- [Authentication Decision Guide](../../../../secure/github-apps/authentication-decision-guide.md) - Choose the right auth method
- [Token Generation](token-generation.md) - Generate installation tokens
- [JWT Authentication](jwt-authentication.md) - App-level authentication
- [OAuth Authentication](oauth-authentication.md) - User-context authentication
- [Error Handling](error-handling/index.md) - Token-specific error patterns
- [Security Best Practices](security-best-practices.md) - Secure token handling

## References

- [Installation Token Documentation](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app)
- [GitHub API Rate Limits](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [Token Expiration Best Practices](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app)
