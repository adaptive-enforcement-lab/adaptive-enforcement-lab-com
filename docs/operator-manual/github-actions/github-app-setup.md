# GitHub Core App for Organizations

This guide describes the concept, setup, and configuration of a GitHub Core App for organization-level automation.

## What is a GitHub Core App?

A **GitHub Core App** is an organization-level GitHub App that provides centralized, secure authentication for GitHub Actions workflows operating across multiple repositories. It serves as the foundational authentication mechanism for org-wide automation.

### Why Use a Core App?

**Traditional Approach (PATs)**:

- Personal Access Tokens tied to individual user accounts
- Token revoked when user leaves organization
- Difficult to audit actions across repositories
- No granular permission control
- Lower rate limits (5000 requests/hour for authenticated users)

**Core App Approach**:

- Organization-owned identity independent of individuals
- Survives personnel changes
- Complete audit trail of all actions
- Fine-grained, repository-scoped permissions
- Higher rate limits (5000 requests/hour per installation)
- Team-based repository access control

### Use Cases

A GitHub Core App enables:

- **Cross-repository operations** - Synchronize files across multiple repositories
- **Team-scoped automation** - Query and operate on team repositories
- **Centralized CI/CD** - Single authentication source for all workflows
- **Compliance automation** - Enforce policies across organization
- **Repository management** - Create, configure, and manage repositories programmatically

## Core App vs. Standard GitHub Apps

| Aspect | Core App | Standard App |
|--------|----------|--------------|
| **Scope** | Organization-wide | Single repository or selected repos |
| **Purpose** | Infrastructure automation | Feature-specific functionality |
| **Permissions** | Broad, covers common operations | Narrow, task-specific |
| **Installation** | All repositories | Selective repositories |
| **Ownership** | Organization-level admin | Project or team |
| **Lifespan** | Permanent infrastructure | Project lifecycle |

## Prerequisites

### Required Access

To create a Core App, you need:

- **Organization owner** role
- Access to organization settings: `https://github.com/organizations/{ORG}/settings/apps`

### Planning Considerations

Before creating the app, determine:

1. **Permission scope** - Which repository and organization permissions are needed
2. **Installation scope** - All repositories or specific teams
3. **Token management** - Where secrets will be stored (repository or organization level)
4. **Naming convention** - Standard naming (e.g., "CORE App", "Automation Core")

## Creating the Core App

### Step 1: Navigate to GitHub Apps

1. Go to **Organization Settings**
2. Select **Developer settings** (left sidebar)
3. Click **GitHub Apps**
4. Click **New GitHub App**

### Step 2: Basic Configuration

Fill in the application details:

| Field | Value | Notes |
|-------|-------|-------|
| **GitHub App name** | `CORE App` | Or your organization's naming convention |
| **Homepage URL** | `https://github.com/{ORG}` | Can be organization homepage |
| **Webhook** | Unchecked | Core apps typically don't use webhooks |
| **Webhook URL** | Leave blank | Not needed for automation |

### Step 3: Repository Permissions

Configure permissions based on your automation needs:

#### Essential Permissions

| Permission | Access Level | Purpose |
|------------|--------------|---------|
| **Contents** | Read & Write | Clone repos, push changes, create branches |
| **Pull Requests** | Read & Write | Create and manage PRs |
| **Metadata** | Read | Access repository metadata (auto-granted) |

#### Optional Permissions

| Permission | Access Level | Use Case |
|------------|--------------|----------|
| **Actions** | Read & Write | Manage workflow files, trigger runs |
| **Administration** | Write | Create repositories, manage settings |
| **Issues** | Read & Write | Automated issue management |
| **Workflows** | Write | Approve workflow runs from forks |

**Principle**: Grant only permissions required for your automation use cases.

### Step 4: Organization Permissions

Configure organization-level permissions:

| Permission | Access Level | Purpose |
|------------|--------------|---------|
| **Members** | Read | Query team membership, access team repositories |

**Critical**: The **Members** permission enables team-scoped queries via GraphQL:

```graphql
{
  organization(login: "{ORG}") {
    team(slug: "{TEAM}") {
      repositories(first: 100) {
        nodes {
          name
          defaultBranchRef {
            name
          }
        }
      }
    }
  }
}
```

Without this permission, team queries return `null`.

### Step 5: Install the App

After creating the app:

1. Click **Install App** (left sidebar)
2. Select **Install on this organization**
3. Choose installation scope:

#### Recommended: All repositories

- Simplifies automation across organization
- New repositories automatically included
- No maintenance of repository selection

#### Alternative: Only select repositories

- Use when testing or limiting scope
- Requires manual updates as repositories are added

### Step 6: Generate Credentials

Generate the authentication credentials:

#### App ID

- Located at top of app settings page
- Format: 6-7 digit number
- Example: `123456`
- Used in workflow configuration

#### Private Key

1. Scroll to **Private keys** section
2. Click **Generate a private key**
3. Downloads a `.pem` file
4. **Store securely** - this file cannot be regenerated
5. File format:

   ```text
   -----BEGIN RSA PRIVATE KEY-----
   MIIEpAIBAAKCAQEA...
   ...
   -----END RSA PRIVATE KEY-----
   ```

**Security Note**: Treat the private key like a password. Never commit to version control.

## Storing Credentials in GitHub

### Repository Secrets

For single-repository usage:

1. Navigate to repository **Settings**
2. Go to **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add two secrets:
   - `CORE_APP_ID`: Numeric app ID
   - `CORE_APP_PRIVATE_KEY`: Complete `.pem` file contents

### Organization Secrets

For organization-wide usage (recommended):

1. Navigate to **Organization Settings**
2. Go to **Secrets and variables** → **Actions**
3. Click **New organization secret**
4. Add secrets with same names as above
5. Configure **Repository access**:
   - **All repositories** - Available to all org repos
   - **Selected repositories** - Choose specific repos

**Advantage**: Single source of truth, centralized rotation.

## Permission Design Patterns

### Read-Only Automation

For reporting and analysis workflows:

```text
Contents: Read
Pull Requests: Read
Issues: Read
Members: Read
```

**Use cases**: Security scanning, metrics collection, compliance reporting

### Standard Automation

For typical cross-repository workflows:

```text
Contents: Read & Write
Pull Requests: Read & Write
Members: Read
```

**Use cases**: File synchronization, automated PR creation, documentation updates

### Full Automation

For infrastructure and repository management:

```text
Contents: Read & Write
Pull Requests: Read & Write
Administration: Write
Actions: Read & Write
Members: Read
```

**Use cases**: Repository provisioning, advanced CI/CD, organization management

## Security Best Practices

### Private Key Security

- ✅ Store in GitHub Secrets or secure vault
- ✅ Rotate every 6-12 months
- ✅ Limit access using environment protection
- ❌ Never commit to repositories
- ❌ Never log or expose in workflow output
- ❌ Never share via unsecured channels

### Permission Principles

1. **Least Privilege** - Grant minimum permissions required
2. **Regular Review** - Audit permissions quarterly
3. **Scope Validation** - Verify token scope before operations
4. **Access Control** - Use environment protection rules

### Token Lifecycle

GitHub App tokens generated in workflows:

- **Lifetime**: 1 hour (automatic expiration)
- **Scope**: Exact permissions granted to app
- **Renewal**: Regenerated per workflow run
- **Revocation**: Revoke app installation to invalidate all tokens

### Audit and Monitoring

Monitor Core App usage:

1. **Audit Log** - Review app actions in organization audit log
2. **Webhook Events** - Optional: Track app activity via webhooks
3. **Rate Limits** - Monitor API usage via response headers
4. **Permission Changes** - Alert on app permission modifications

## Installation Scopes

### Organization-Wide Installation

**Configuration**: All repositories

**Advantages**:

- New repositories automatically included
- No maintenance overhead
- Consistent access across organization

**Considerations**:

- Requires trust in workflows
- Broader attack surface if compromised
- More careful permission design needed

### Team-Scoped Installation

**Configuration**: Selected repositories (team members)

**Advantages**:

- Limited blast radius
- Team-level isolation
- Granular control

**Considerations**:

- Manual maintenance as teams change
- Complexity managing multiple apps
- GraphQL queries still require Members permission

### Hybrid Approach

**Pattern**: Organization-wide installation + workflow-level filtering

```yaml
# Workflow only operates on specific team
- name: Fetch team repositories
  run: |
    gh api graphql -f query='
    {
      organization(login: "$ORG") {
        team(slug: "platform") {
          repositories { ... }
        }
      }
    }'
```

**Advantages**: Central app, team-scoped operations

## Common Permission Requirements

### File Distribution Workflows

**Required**:

- Contents: Read & Write
- Pull Requests: Read & Write
- Members: Read (for team queries)

### CI/CD Orchestration

**Required**:

- Actions: Read & Write
- Contents: Read
- Workflows: Write (for fork approval)

### Repository Management

**Required**:

- Administration: Write
- Contents: Read & Write
- Members: Read

### Compliance Scanning

**Required**:

- Contents: Read
- Pull Requests: Read
- Issues: Read & Write (for creating issues)

## Troubleshooting

### App Installation Issues

**Symptom**: Cannot install app on organization

**Checks**:

1. Verify organization owner role
2. Check organization permissions allow app installation
3. Review organization security settings

### Permission Denied

**Symptom**: Workflows fail with `403 Forbidden`

**Checks**:

1. Verify app has required permissions in settings
2. Check app is installed on target repositories
3. Confirm organization secrets are accessible

### Team Query Returns Null

**Symptom**: GraphQL query for team repositories returns `"team": null`

**Checks**:

1. Verify "Members" organization permission is granted
2. Confirm app is installed at organization level
3. Check team exists and has repositories

## Maintenance

### Regular Tasks

| Task | Frequency | Action |
|------|-----------|--------|
| **Permission Review** | Quarterly | Audit and adjust permissions |
| **Key Rotation** | Semi-annually | Generate new private key |
| **Usage Audit** | Monthly | Review audit logs |
| **Secret Access** | Quarterly | Review who can access secrets |

### Key Rotation Process

1. Generate new private key in app settings
2. Update `CORE_APP_PRIVATE_KEY` secret
3. Monitor workflows for successful authentication
4. Delete old private key from app settings
5. Document rotation in security log

### Decommissioning

When removing a Core App:

1. **Identify Dependencies** - List all workflows using the app
2. **Migration Plan** - Prepare alternative authentication
3. **Communication** - Notify affected teams
4. **Uninstall** - Remove app installation
5. **Cleanup** - Delete associated secrets
6. **Verification** - Confirm no workflows are broken

## Next Steps

After setting up your Core App:

1. **[GitHub Actions Integration](./actions-integration.md)** - Learn how to use the app in workflows
2. **[Distribution Workflows](./contributing-distribution.md)** - Example use case patterns
3. **Testing** - Validate app permissions with test workflows
4. **Documentation** - Document your organization's app usage

## References

- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [GitHub Apps Permissions](https://docs.github.com/en/rest/overview/permissions-required-for-github-apps)
- [GitHub GraphQL API](https://docs.github.com/en/graphql)
- [Organization Security Best Practices](https://docs.github.com/en/organizations/keeping-your-organization-secure)
