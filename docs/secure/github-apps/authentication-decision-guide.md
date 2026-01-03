---
title: GitHub App Authentication Decision Guide
description: >-
  Choose the right authentication method for your GitHub App. Decision trees, use cases, and method comparison for JWT, installation tokens, and OAuth flows.
tags:
  - github
  - security
  - authentication
  - developers
  - operators
---

# GitHub App Authentication Decision Guide

GitHub Apps support three distinct authentication methods, each designed for different use cases. This guide helps you choose the right approach.

!!! abstract "Three Authentication Methods"

    - **JWT (JSON Web Token)** - App-level authentication for managing the app itself
    - **Installation Tokens** - Repository-scoped tokens for automation workflows
    - **OAuth** - User-context authentication for user-driven operations

## Quick Decision Tree

```mermaid
flowchart TD
    A["What are you trying to do?"] --> B{"Who initiates<br/>the action?"}

    B -->|"Automated workflow"| C{"What scope<br/>is needed?"}
    B -->|"User action"| D["OAuth User Token<br/>User-context operations"]

    C -->|"App management<br/>(list installations,<br/>update settings)"| E["JWT Token<br/>App-level access"]
    C -->|"Repository operations<br/>(read/write code,<br/>create PRs)"| F["Installation Token<br/>Repository-scoped"]

    %% Ghostty Hardcore Theme
    style A fill:#515354,stroke:#ccccc7,stroke-width:2px,color:#ccccc7
    style B fill:#fd971e,stroke:#e6db74,stroke-width:2px,color:#1b1d1e
    style C fill:#65d9ef,stroke:#a3babf,stroke-width:2px,color:#1b1d1e
    style D fill:#a7e22e,stroke:#bded5f,stroke-width:2px,color:#1b1d1e
    style E fill:#9e6ffe,stroke:#9e6ffe,stroke-width:2px,color:#1b1d1e
    style F fill:#f92572,stroke:#ff669d,stroke-width:2px,color:#1b1d1e
```

## Detailed Decision Tree

```mermaid
flowchart TD
    A["GitHub App Authentication"] --> B{"Do you need to<br/>manage the app itself?"}

    B -->|"Yes<br/>(app settings, installations)"| C["Use JWT Token"]
    C --> C1["Generate from private key"]
    C1 --> C2["Valid for 10 minutes"]
    C2 --> C3["App-level permissions only"]

    B -->|"No<br/>(repository operations)"| D{"Who triggers<br/>the action?"}

    D -->|"Automated process<br/>(GitHub Actions, CI)"| E["Use Installation Token"]
    E --> E1["Generate via GitHub API<br/>or actions/create-github-app-token"]
    E1 --> E2["Valid for 1 hour"]
    E2 --> E3["Repository-scoped permissions"]

    D -->|"Human user<br/>(web app, CLI tool)"| F["Use OAuth Token"]
    F --> F1["Web flow or device flow"]
    F1 --> F2["Valid until revoked"]
    F2 --> F3["User-context permissions"]

    %% Ghostty Hardcore Theme
    style A fill:#515354,stroke:#ccccc7,stroke-width:2px,color:#ccccc7
    style B fill:#fd971e,stroke:#e6db74,stroke-width:2px,color:#1b1d1e
    style C fill:#9e6ffe,stroke:#9e6ffe,stroke-width:2px,color:#1b1d1e
    style C1 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style C2 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style C3 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style D fill:#fd971e,stroke:#e6db74,stroke-width:2px,color:#1b1d1e
    style E fill:#f92572,stroke:#ff669d,stroke-width:2px,color:#1b1d1e
    style E1 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style E2 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style E3 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style F fill:#a7e22e,stroke:#bded5f,stroke-width:2px,color:#1b1d1e
    style F1 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style F2 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
    style F3 fill:#515354,stroke:#ccccc7,stroke-width:1px,color:#ccccc7
```

## Authentication Method Comparison

| Aspect | JWT Token | Installation Token | OAuth Token |
| -------- | ----------- | -------------------- | ------------- |
| **Primary Use** | App management | Automation workflows | User operations |
| **Scope** | App-level | Repository/org-level | User permissions |
| **Lifespan** | 10 minutes | 1 hour (default) | Until revoked |
| **Generation** | Private key signing | GitHub API | OAuth flow |
| **Permissions** | App metadata only | App's granted permissions | User's permissions |
| **Rate Limit** | 5,000/hour per app | 5,000/hour per installation | 5,000/hour per user |
| **Typical Context** | Bootstrap, diagnostics | CI/CD, automation | Interactive apps |
| **GitHub Actions** | Manual implementation | `actions/create-github-app-token` | Rarely used |

## Use Cases by Authentication Method

### JWT Token Use Cases

!!! example "When to Use JWT"

    - **List app installations** - Enumerate where the app is installed
    - **Retrieve app manifest** - Get the app's configuration and permissions
    - **Manage installations** - Suspend or configure installations
    - **Bootstrap automation** - Generate installation tokens dynamically
    - **Diagnostics and auditing** - Check app status and metadata

**Example Scenario**: A workflow needs to discover all repositories where the app is installed, then process each one.

```yaml
# Generate JWT → List installations → Generate installation tokens for each
```

!!! warning "JWT Limitations"

    - Cannot access repository contents
    - Cannot create issues or pull requests
    - Cannot commit code
    - 10-minute expiration requires frequent regeneration

### Installation Token Use Cases

!!! example "When to Use Installation Tokens"

    - **Cross-repository automation** - Synchronize files across repos
    - **CI/CD workflows** - Build, test, and deploy operations
    - **Pull request automation** - Create, update, or merge PRs
    - **Repository management** - Create repos, manage settings
    - **Team-scoped operations** - Work with team repositories
    - **Compliance automation** - Enforce policies across org

**Example Scenario**: A GitHub Actions workflow that distributes security policies to all organization repositories.

```yaml
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: my-organization
```

!!! tip "Most Common Method"

    Installation tokens are the workhorse of GitHub App automation. Use them for 90% of automation scenarios.

### OAuth Token Use Cases

!!! example "When to Use OAuth"

    - **Web applications** - Apps that act on behalf of signed-in users
    - **CLI tools** - Command-line tools requiring user authorization
    - **User-specific operations** - Actions that must be attributed to a user
    - **Personal repositories** - Access to user's own repos
    - **User notifications** - Send notifications as the user
    - **User context required** - Operations that need user identity

**Example Scenario**: A web application that creates GitHub issues on behalf of the authenticated user.

```text
User clicks "Create Issue" → OAuth flow → Token generated → Issue created as user
```

!!! warning "User Context Required"

    OAuth is the only method that preserves user identity in GitHub's audit logs. Use it when user attribution is important.

## Authentication Flow Comparison

### JWT Flow

```mermaid
sequenceDiagram
    participant W as Workflow
    participant K as Private Key
    participant G as GitHub API

    W->>K: Load private key
    K->>W: Return key
    W->>W: Generate JWT<br/>(sign with key)
    W->>G: API request with JWT
    G->>W: App-level response

    Note over W,G: Valid for 10 minutes
```

### Installation Token Flow

```mermaid
sequenceDiagram
    participant W as Workflow
    participant A as actions/create-github-app-token
    participant G as GitHub API
    participant R as Repository

    W->>A: Provide app-id & private-key
    A->>A: Generate JWT
    A->>G: Request installation token
    G->>A: Return installation token
    A->>W: Set GH_TOKEN env var
    W->>R: Repository operations

    Note over W,R: Valid for 1 hour
```

### OAuth Flow

```mermaid
sequenceDiagram
    participant U as User
    participant A as Your App
    participant G as GitHub
    participant R as Repository

    U->>A: Initiate login
    A->>G: Redirect to GitHub OAuth
    U->>G: Authorize app
    G->>A: Return authorization code
    A->>G: Exchange code for token
    G->>A: Return OAuth token
    A->>R: Operations as user

    Note over U,R: Valid until revoked
```

## Security Considerations by Method

### JWT Security

!!! warning "JWT Best Practices"

    - **Never commit private keys** - Store in GitHub Secrets or vault
    - **Rotate keys regularly** - At least every 90 days
    - **Minimal JWT permissions** - JWT only grants app-level access
    - **Short-lived tokens** - 10-minute expiration is a feature
    - **Audit key usage** - Monitor when and where JWTs are generated

### Installation Token Security

!!! warning "Installation Token Best Practices"

    - **Use `actions/create-github-app-token`** - Handles generation securely
    - **Respect token expiration** - Regenerate after 1 hour
    - **Scope to minimum permissions** - Grant only needed permissions
    - **Use organization scope wisely** - `owner: org-name` grants broad access
    - **Monitor rate limits** - 5,000/hour per installation

### OAuth Security

!!! warning "OAuth Best Practices"

    - **Use state parameter** - Prevent CSRF attacks
    - **Validate redirect URIs** - Only allow registered URIs
    - **Secure token storage** - Encrypt at rest
    - **Implement token refresh** - Handle expiration gracefully
    - **Request minimal scopes** - Only ask for needed permissions

## Common Patterns and Anti-Patterns

### ✅ Recommended Patterns

!!! tip "GitHub Actions Automation"

    ```yaml
    # ✅ Use actions/create-github-app-token for workflows
    - uses: actions/create-github-app-token@v2
      with:
        app-id: ${{ secrets.CORE_APP_ID }}
        private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
        owner: adaptive-enforcement-lab
    ```

!!! tip "Bootstrap Pattern"

    ```yaml
    # ✅ JWT → List installations → Generate installation tokens
    # Use JWT only for discovery, then switch to installation tokens
    ```

!!! tip "User Attribution"

    ```yaml
    # ✅ Use OAuth when user identity matters
    # Example: Creating issues that should show user as author
    ```

### ❌ Anti-Patterns

!!! danger "Wrong Token Type"

    ```yaml
    # ❌ Don't use JWT for repository operations
    # JWT cannot access repository contents

    # ❌ Don't use installation token for app management
    # Installation tokens can't list other installations

    # ❌ Don't use OAuth in GitHub Actions
    # No user context available in automated workflows
    ```

!!! danger "Security Mistakes"

    ```yaml
    # ❌ Don't hardcode private keys
    private_key: "-----BEGIN RSA PRIVATE KEY-----\n..."

    # ❌ Don't use long-lived tokens when short-lived work
    # Installation tokens expire for a reason

    # ❌ Don't grant excessive permissions
    # Follow principle of least privilege
    ```

## Decision Checklist

Use this checklist to determine the right authentication method:

### Choose JWT if

- [ ] You need to list app installations
- [ ] You're retrieving app metadata or manifest
- [ ] You're managing installation configuration
- [ ] You're building a token generation service
- [ ] You need app-level diagnostics

### Choose Installation Token if

- [ ] You're automating repository operations
- [ ] You're running in GitHub Actions
- [ ] You need to access repository contents
- [ ] You need to create pull requests or issues
- [ ] You're implementing cross-repo workflows
- [ ] You need organization-scoped access

### Choose OAuth if

- [ ] You're building a web application
- [ ] Users need to authorize your app
- [ ] Operations must be attributed to users
- [ ] You need user-context permissions
- [ ] You're building a CLI tool for users
- [ ] User identity is important for audit trail

## Next Steps

### Learn More About Each Method

- **JWT Authentication** - [JWT Authentication Guide](../../patterns/github-actions/actions-integration/jwt-authentication/index.md)
- **Installation Tokens** - [Token Generation Guide](../../patterns/github-actions/actions-integration/token-generation/index.md)
- **OAuth Authentication** - [OAuth Authentication Guide](../../patterns/github-actions/actions-integration/oauth-authentication/index.md)

### Additional Resources

- [GitHub App Setup](index.md) - Create your GitHub App
- [Storing Credentials](storing-credentials/index.md) - Secure credential management
- [Security Best Practices](security-best-practices.md) - App security guidelines
- [Token Lifecycle Management](../../patterns/github-actions/actions-integration/token-lifecycle/index.md) - Token expiration, refresh strategies, and caching patterns

### Common Workflows

- [Cross-Repository Automation](../../patterns/github-actions/actions-integration/token-generation/workflow-patterns.md)
- [Error Handling](../../patterns/github-actions/actions-integration/error-handling/index.md)
- [Performance Optimization](../../patterns/github-actions/actions-integration/performance-optimization.md)

## References

- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [GitHub Apps Authentication](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [OAuth Apps vs GitHub Apps](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/differences-between-github-apps-and-oauth-apps)
