---
title: Storing Credentials
description: >-
  Securely store GitHub App credentials as organization or repository secrets.
  Best practices for secret management and access control.
---

# Storing Credentials in GitHub

How to securely store your Core App credentials for use in GitHub Actions workflows.

## Repository Secrets

For single-repository usage:

1. Navigate to repository **Settings**
2. Go to **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add two secrets:
   - `CORE_APP_ID`: Numeric app ID
   - `CORE_APP_PRIVATE_KEY`: Complete `.pem` file contents

## Organization Secrets

For organization-wide usage (recommended):

1. Navigate to **Organization Settings**
2. Go to **Secrets and variables** → **Actions**
3. Click **New organization secret**
4. Add secrets with same names as above
5. Configure **Repository access**:
   - **All repositories** - Available to all org repos
   - **Selected repositories** - Choose specific repos

!!! success "Advantage"

    Single source of truth, centralized rotation.

## Secret Naming Conventions

| Secret Name | Contents | Example |
|-------------|----------|---------|
| `CORE_APP_ID` | Numeric app ID | `123456` |
| `CORE_APP_PRIVATE_KEY` | Complete PEM file contents | `-----BEGIN RSA PRIVATE KEY-----...` |

## Best Practices

### Repository vs Organization Secrets

| Aspect | Repository Secrets | Organization Secrets |
|--------|-------------------|---------------------|
| **Scope** | Single repository | Multiple repositories |
| **Management** | Per-repo updates | Centralized updates |
| **Rotation** | Update each repo | Update once |
| **Access Control** | Repository admins | Organization admins |

!!! tip "Recommendation"

    Use organization secrets for Core Apps to simplify rotation and management.

### Secret Access Control

For organization secrets, consider:

- **All repositories** - When app needs org-wide access
- **Selected repositories** - When limiting to specific workflows
- **Private repositories only** - Additional security layer

### Workflow Access

Reference secrets in workflows:

```yaml
- name: Generate token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
```

## Environment Protection

For additional security, use GitHub Environments:

1. Create an environment (e.g., `production`)
2. Add secrets to the environment
3. Configure protection rules:
   - Required reviewers
   - Wait timer
   - Deployment branches

```yaml
jobs:
  deploy:
    environment: production
    steps:
      - name: Generate token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
```

## Next Steps

- [Review permission patterns](permission-patterns.md)
- [Understand security best practices](security-best-practices.md)
