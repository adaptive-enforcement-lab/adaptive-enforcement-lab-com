---
title: GitHub App Authentication Flows
description: >-
  Sequence diagrams for JWT, installation token, and OAuth authentication flows. Visual guide to GitHub App authentication patterns.
tags:
  - github
  - security
  - authentication
  - developers
  - operators
---

# GitHub App Authentication Flows

Visual sequence diagrams showing how each GitHub App authentication method works.

!!! info "Flow Selection Guide"
    Choose based on who initiates the action and what scope is needed. JWT for app management, Installation Token for automation, OAuth for user-driven operations.

## JWT Flow

```mermaid
sequenceDiagram

%% Ghostty Hardcore Theme
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

**Use case**: App management operations (list installations, retrieve app metadata)

**Key points**:

- Signed with private key
- 10-minute expiration
- App-level permissions only
- Cannot access repository contents

## Installation Token Flow

```mermaid
sequenceDiagram

%% Ghostty Hardcore Theme
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

**Use case**: Automation workflows (CI/CD, cross-repo operations)

**Key points**:

- Generated via GitHub API or actions/create-github-app-token
- 1-hour expiration (default)
- Repository/organization-scoped permissions
- Most common method for GitHub Actions

## OAuth Flow

```mermaid
sequenceDiagram

%% Ghostty Hardcore Theme
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

**Use case**: User-driven operations (web apps, CLI tools)

**Key points**:

- Requires user authorization
- Valid until revoked
- User-context permissions
- Preserves user identity in audit logs

## Flow Selection Quick Reference

| Flow Type | Initiator | Lifespan | Typical Use |
|-----------|-----------|----------|-------------|
| **JWT** | System | 10 minutes | App management, bootstrap |
| **Installation Token** | System | 1 hour | CI/CD, automation |
| **OAuth** | User | Until revoked | Web apps, CLI tools |

## Related Content

- **[Authentication Decision Guide](authentication-decision-guide.md)** - Choose the right authentication method
- **[JWT Authentication](../../patterns/github-actions/actions-integration/jwt-authentication/index.md)** - Detailed JWT guide
- **[Token Generation](../../patterns/github-actions/actions-integration/token-generation/index.md)** - Installation token patterns
- **[OAuth Authentication](../../patterns/github-actions/actions-integration/oauth-authentication/index.md)** - OAuth implementation

*Three flows. Three purposes. Choose based on who initiates and what scope is needed.*
