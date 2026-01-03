---
title: OAuth Security and Troubleshooting
description: >-
  Security best practices, troubleshooting, and rate limits for GitHub OAuth authentication. Common error scenarios and solutions.
---

## Common Use Cases

### Use Case 1: Web Application with User Attribution

Create GitHub issues as the authenticated user.

```python
@app.route('/create-issue', methods=['POST'])
def create_user_issue():
    if 'github_token' not in session:
        return redirect(url_for('login'))

    issue_data = request.json

    response = requests.post(
        f"https://api.github.com/repos/{issue_data['repo']}/issues",
        json={
            'title': issue_data['title'],
            'body': issue_data['body'],
            'labels': issue_data.get('labels', []),
        },
        headers={
            'Authorization': f"Bearer {session['github_token']}",
            'Accept': 'application/vnd.github+json',
        },
    )

    return response.json()
```

### Use Case 2: CLI Tool with Device Flow

```bash
#!/bin/bash
# Example CLI tool using device flow authentication

gh-cli-tool create-pr \
  --repo adaptive-enforcement-lab/example-repo \
  --title "Feature: Add new functionality" \
  --body "PR created via CLI tool" \
  --base main \
  --head feature-branch

# Tool automatically:
# 1. Checks for cached token
# 2. Verifies token validity
# 3. Initiates device flow if needed
# 4. Creates PR with user attribution
```

### Use Case 3: Personal Repository Access

Access user's private repositories.

```python
def list_user_repos(access_token, visibility='private'):
    """List user's repositories"""

    response = requests.get(
        'https://api.github.com/user/repos',
        params={'visibility': visibility},
        headers={
            'Authorization': f'Bearer {access_token}',
            'Accept': 'application/vnd.github+json',
        },
    )

    return response.json()

# Get user's private repos
private_repos = list_user_repos(user_token, visibility='private')
for repo in private_repos:
    print(f"{repo['full_name']} - {repo['description']}")
```

### Use Case 4: User Notification Management

```python
def mark_notifications_read(access_token):
    """Mark all notifications as read for the user"""

    response = requests.put(
        'https://api.github.com/notifications',
        json={'read': True},
        headers={
            'Authorization': f'Bearer {access_token}',
            'Accept': 'application/vnd.github+json',
        },
    )

    return response.status_code == 205

# Usage
if mark_notifications_read(user_token):
    print("All notifications marked as read")
```

## Security Best Practices

### 1. State Parameter (CSRF Protection)

```python
# ✅ GOOD: Generate cryptographically secure state
import secrets
state = secrets.token_urlsafe(32)
session['oauth_state'] = state

# ❌ BAD: Predictable or missing state
state = "static-string"  # Never do this
```

### 2. Redirect URI Validation

```python
# ✅ GOOD: Validate redirect URI matches registered URI
ALLOWED_REDIRECT_URIS = [
    'https://your-app.com/auth/callback',
    'https://your-app.com/oauth/callback',
]

if redirect_uri not in ALLOWED_REDIRECT_URIS:
    raise ValueError("Invalid redirect URI")

# ❌ BAD: Accept any redirect URI
# This enables open redirect vulnerabilities
```

### 3. Secure Token Storage

```python
# ✅ GOOD: Encrypt tokens at rest
encrypted_token = encrypt_token(access_token)
db.store(user_id, encrypted_token)

# ❌ BAD: Store tokens in plain text
db.store(user_id, access_token)  # Never do this
```

### 4. Token Scope Minimization

```python
# ✅ GOOD: Request only needed scopes
scope = 'repo:status read:user'

# ❌ BAD: Request excessive permissions
scope = 'repo admin:org delete_repo'  # Too broad
```

### 5. Token Revocation

```python
def revoke_token(access_token, client_id, client_secret):
    """Revoke an OAuth token"""

    response = requests.delete(
        f'https://api.github.com/applications/{client_id}/token',
        auth=(client_id, client_secret),
        json={'access_token': access_token},
        headers={'Accept': 'application/vnd.github+json'},
    )

    return response.status_code == 204

# Always revoke on logout
@app.route('/logout')
def logout():
    if 'github_token' in session:
        revoke_token(
            session['github_token'],
            GITHUB_CLIENT_ID,
            GITHUB_CLIENT_SECRET,
        )
    session.clear()
    return redirect('/')
```

## Troubleshooting

### Invalid State Parameter

```text
Error: The state parameter does not match
```

**Causes**:

- Session expired between redirect
- State not properly stored
- CSRF attack attempt

**Solution**:

```python
# Ensure session is configured correctly
app.config['SESSION_COOKIE_SECURE'] = True  # HTTPS only
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'

# Validate state before proceeding
if request.args.get('state') != session.pop('oauth_state', None):
    abort(400, "Invalid state parameter")
```

### Token Rejected (401 Unauthorized)

```text
Error: Bad credentials
```

**Causes**:

- Token revoked by user
- Token expired (if using time-limited tokens)
- Invalid token format

**Solution**:

```python
# Always check token validity before use
status = check_token_status(access_token)
if not status['valid']:
    # Re-authenticate user
    return redirect(url_for('login'))
```

### Insufficient Permissions (403 Forbidden)

```text
Error: Resource not accessible by integration
```

**Cause**: Token lacks required scope.

**Solution**:

```python
# Request additional scopes during OAuth flow
scope = 'repo user admin:org'  # Add needed scopes

# Check required scopes
response = requests.get(
    'https://api.github.com/user',
    headers={'Authorization': f'Bearer {token}'},
)
granted_scopes = response.headers.get('X-OAuth-Scopes', '').split(', ')
print(f"Granted scopes: {granted_scopes}")
```

### Device Code Expired

```text
Error: The device code has expired
```

**Cause**: User took too long to authorize (15 minutes default).

**Solution**:

```python
# Implement timeout and retry
def device_flow_with_timeout(client_id, timeout=900):  # 15 minutes
    start_time = time.time()
    device_data = request_device_code(client_id)

    while time.time() - start_time < timeout:
        # Poll for token
        # ...
        if token:
            return token

    # Expired - request new device code
    return device_flow_with_timeout(client_id, timeout)
```

## Rate Limits

OAuth tokens are subject to user-level rate limits: **5,000 requests/hour per user**.

### Check Rate Limit

```python
def check_rate_limit(access_token):
    """Check current rate limit status"""

    response = requests.get(
        'https://api.github.com/rate_limit',
        headers={
            'Authorization': f'Bearer {access_token}',
            'Accept': 'application/vnd.github+json',
        },
    )

    data = response.json()
    core = data['resources']['core']

    return {
        'limit': core['limit'],
        'remaining': core['remaining'],
        'reset': datetime.fromtimestamp(core['reset']),
    }

# Usage
limit_status = check_rate_limit(user_token)
print(f"Rate limit: {limit_status['remaining']}/{limit_status['limit']}")
print(f"Resets at: {limit_status['reset']}")
```

## When NOT to Use OAuth

!!! danger "Don't Use OAuth For"

    - **GitHub Actions workflows** - No user present to authorize
    - **Automated CI/CD** - Use installation tokens instead
    - **Server-to-server automation** - Use installation tokens
    - **Cross-organization operations** - Use installation tokens with org scope
    - **Scheduled jobs** - No user interaction possible

## Related Documentation

- [Authentication Decision Guide](../../../../secure/github-apps/authentication-decision-guide.md) - Choose the right auth method
- [JWT Authentication](../jwt-authentication/index.md) - App-level authentication
- [Token Generation](../token-generation/index.md) - Installation token automation
- [Security Best Practices](../../../../secure/github-apps/security-best-practices.md) - Secure token handling
- [Storing Credentials](../../../../secure/github-apps/storing-credentials/index.md) - Credential management

## References

- [GitHub Apps OAuth Documentation](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-with-a-github-app-on-behalf-of-a-user)
- [OAuth 2.0 Device Flow (RFC 8628)](https://tools.ietf.org/html/rfc8628)
- [OAuth 2.0 Authorization Framework](https://tools.ietf.org/html/rfc6749)
- [GitHub OAuth Scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps)
- [Web Application Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#web-application-flow)
- [Device Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps#device-flow)
