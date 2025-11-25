# Creating the Core App

Step-by-step guide to creating a GitHub Core App for your organization.

## Step 1: Navigate to GitHub Apps

1. Go to **Organization Settings**
2. Select **Developer settings** (left sidebar)
3. Click **GitHub Apps**
4. Click **New GitHub App**

## Step 2: Basic Configuration

Fill in the application details:

| Field | Value | Notes |
|-------|-------|-------|
| **GitHub App name** | `CORE App` | Or your organization's naming convention |
| **Homepage URL** | `https://github.com/{ORG}` | Can be organization homepage |
| **Webhook** | Unchecked | Core apps typically don't use webhooks |
| **Webhook URL** | Leave blank | Not needed for automation |

## Step 3: Repository Permissions

Configure permissions based on your automation needs:

### Essential Permissions

| Permission | Access Level | Purpose |
|------------|--------------|---------|
| **Contents** | Read & Write | Clone repos, push changes, create branches |
| **Pull Requests** | Read & Write | Create and manage PRs |
| **Metadata** | Read | Access repository metadata (auto-granted) |

### Optional Permissions

| Permission | Access Level | Use Case |
|------------|--------------|----------|
| **Actions** | Read & Write | Manage workflow files, trigger runs |
| **Administration** | Write | Create repositories, manage settings |
| **Issues** | Read & Write | Automated issue management |
| **Workflows** | Write | Approve workflow runs from forks |

!!! tip "Principle of Least Privilege"

    Grant only permissions required for your automation use cases.

## Step 4: Organization Permissions

Configure organization-level permissions:

| Permission | Access Level | Purpose |
|------------|--------------|---------|
| **Members** | Read | Query team membership, access team repositories |

!!! warning "Critical Permission"

    The **Members** permission enables team-scoped queries via GraphQL:

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

## Step 5: Install the App

After creating the app:

1. Click **Install App** (left sidebar)
2. Select **Install on this organization**
3. Choose installation scope:

### Recommended: All repositories

- Simplifies automation across organization
- New repositories automatically included
- No maintenance of repository selection

### Alternative: Only select repositories

- Use when testing or limiting scope
- Requires manual updates as repositories are added

## Step 6: Generate Credentials

Generate the authentication credentials:

### App ID

- Located at top of app settings page
- Format: 6-7 digit number
- Example: `123456`
- Used in workflow configuration

### Private Key

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

!!! danger "Security Note"

    Treat the private key like a password. Never commit to version control.

## Next Steps

Once you've created the app and generated credentials:

- [Store the credentials securely](storing-credentials.md)
- [Review permission patterns](permission-patterns.md)
- [Understand security best practices](security-best-practices.md)
