# GitHub Actions Integration with Core App

This guide explains how to integrate your GitHub Core App with GitHub Actions workflows for organization-level automation.

## Prerequisites

Before integrating, ensure you have:

1. **Core App created and installed** - See [GitHub App Setup](./github-app-setup.md)
2. **Secrets configured** - `CORE_APP_ID` and `CORE_APP_PRIVATE_KEY` stored in GitHub
3. **Required permissions** - App has permissions for your automation tasks

## Token Generation Action

GitHub provides the official `actions/create-github-app-token` action for generating short-lived tokens from your Core App credentials.

### Basic Usage

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - name: Generate Core App Token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
```

**Output**: The action generates a token accessible via `${{ steps.app_token.outputs.token }}`

### Organization-Scoped Tokens

To generate tokens with organization-wide access:

```yaml
- name: Generate Org-Scoped Token
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: your-org  # Critical: enables org-scoped access
```

**Critical Parameter**:
- **`owner`** - MUST be specified for organization-level operations
- Without `owner`, tokens are scoped only to the current repository
- Value must match your GitHub organization name exactly

### Repository-Scoped Tokens

For operations limited to specific repositories:

```yaml
- name: Generate Repo-Scoped Token
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    repositories: |
      repo1
      repo2
      repo3
```

**Use case**: Operating on specific repositories without org-wide access

## Using Generated Tokens

### With GitHub CLI (gh)

The most common integration is with the GitHub CLI:

```yaml
- name: Use token with gh CLI
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api /repos/${{ github.repository }}/issues
```

**Environment Variable**: `GH_TOKEN` is automatically recognized by `gh`

### With Git Operations

For git clone, push, and other operations:

```yaml
- name: Clone repository with Core App
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh repo clone org/repository target-dir

- name: Configure git authentication
  working-directory: target-dir
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    git config --local credential.helper \
      '!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f'
```

### With actions/checkout

Use the token with the checkout action:

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    token: ${{ steps.app_token.outputs.token }}
    repository: org/target-repo
```

**Advantage**: Subsequent git operations use the Core App token

### With GraphQL API

Query organization data using GraphQL:

```yaml
- name: Query organization
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api graphql -f query='
    {
      organization(login: "your-org") {
        repositories(first: 10) {
          nodes {
            name
            url
          }
        }
      }
    }'
```

### With REST API

Use the token with REST API calls:

```yaml
- name: Call REST API
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api /orgs/your-org/repos --jq '.[].name'
```

## Common Workflow Patterns

### Pattern 1: Query Team Repositories

```yaml
name: Team Repository Operations
on:
  workflow_dispatch:

jobs:
  query_team_repos:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Fetch team repositories
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          REPOS=$(gh api graphql -f query='
          {
            organization(login: "your-org") {
              team(slug: "engineering") {
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
          }' --jq '.data.organization.team.repositories.nodes')

          echo "$REPOS" | jq -r '.[].name'
```

**Requirements**: Core App must have "Members" organization permission

### Pattern 2: Cross-Repository File Operations

```yaml
name: Distribute File
on:
  push:
    paths:
      - 'shared/config.yml'

jobs:
  distribute:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repo: [repo1, repo2, repo3]
    steps:
      - name: Checkout source
        uses: actions/checkout@v4

      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Clone target repository
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          gh repo clone your-org/${{ matrix.repo }} target

      - name: Copy file
        run: |
          cp shared/config.yml target/config.yml

      - name: Commit and push
        working-directory: target
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          git config user.name "automation-bot"
          git config user.email "automation@your-org.com"

          git add config.yml
          git commit -m "chore: update config.yml"
          git push
```

**Requirements**: Core App needs Contents: Read & Write permission

### Pattern 3: Create Pull Requests

```yaml
name: Automated PR Creation
on:
  workflow_dispatch:
    inputs:
      target_repo:
        description: 'Target repository'
        required: true

jobs:
  create_pr:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Clone repository
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          gh repo clone your-org/${{ inputs.target_repo }} repo

      - name: Create branch and changes
        working-directory: repo
        run: |
          git checkout -b automated-update
          echo "# Update" >> README.md

          git config user.name "automation-bot"
          git config user.email "automation@your-org.com"
          git add README.md
          git commit -m "docs: automated update"

      - name: Push and create PR
        working-directory: repo
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          git push -u origin automated-update

          gh pr create \
            --title "chore: automated update" \
            --body "Automated changes from workflow" \
            --base main \
            --head automated-update
```

**Requirements**: Core App needs Contents: Write and Pull Requests: Write

### Pattern 4: Matrix Strategy with Dynamic Repositories

```yaml
name: Multi-Repository Operation
on:
  workflow_dispatch:

jobs:
  fetch_repos:
    runs-on: ubuntu-latest
    outputs:
      repos: ${{ steps.get_repos.outputs.repos }}
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Fetch repositories
        id: get_repos
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          REPOS=$(gh api /orgs/your-org/repos \
            --jq 'map({name: .name, default_branch: .default_branch})')
          echo "repos=$REPOS" >> $GITHUB_OUTPUT

  process:
    needs: fetch_repos
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repo: ${{ fromJson(needs.fetch_repos.outputs.repos) }}
      fail-fast: false
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Process repository
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          echo "Processing ${{ matrix.repo.name }}"
          gh repo view your-org/${{ matrix.repo.name }}
```

**Pattern**: Fetch repos dynamically, then process each in parallel

## Token Scope Validation

### Verify Organization Access

Test if your token has organization-level permissions:

```yaml
- name: Validate org access
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    # Should succeed if owner parameter was specified
    gh api /orgs/your-org/members | jq 'length'
```

### Verify Team Query Access

Test if your token can query team repositories:

```yaml
- name: Validate team access
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    RESULT=$(gh api graphql -f query='
    {
      organization(login: "your-org") {
        team(slug: "engineering") {
          name
        }
      }
    }' --jq '.data.organization.team')

    if [ "$RESULT" = "null" ]; then
      echo "❌ Team query failed - check Members permission"
      exit 1
    fi

    echo "✅ Team query successful"
```

## Workflow Permissions

### Required Workflow Permissions

Declare minimum permissions for workflows using Core App tokens:

```yaml
name: Example Workflow

on:
  push:
    branches: [main]

permissions:
  contents: read  # For checking out code
  id-token: write  # For generating Core App tokens

jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org
```

**Key Permissions**:
- `contents: read` - Required for checkout action
- `id-token: write` - Required for generating app tokens

### Job-Level vs Workflow-Level Permissions

```yaml
# Workflow-level (applies to all jobs)
permissions:
  contents: read
  id-token: write

jobs:
  job1:
    runs-on: ubuntu-latest
    # Inherits workflow permissions

  job2:
    runs-on: ubuntu-latest
    permissions:
      # Override for this job only
      contents: write
      id-token: write
```

## Error Handling

### Handle Token Generation Failures

```yaml
- name: Generate token
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: your-org
  continue-on-error: true

- name: Check token generation
  if: steps.app_token.outcome == 'failure'
  run: |
    echo "❌ Token generation failed"
    echo "Check: App ID, Private Key, and App installation"
    exit 1
```

### Handle API Rate Limits

```yaml
- name: API call with retry
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    MAX_RETRIES=3
    RETRY_DELAY=60

    for i in $(seq 1 $MAX_RETRIES); do
      if gh api /orgs/your-org/repos; then
        exit 0
      fi

      echo "Retry $i/$MAX_RETRIES after ${RETRY_DELAY}s"
      sleep $RETRY_DELAY
    done

    echo "❌ Failed after $MAX_RETRIES retries"
    exit 1
```

### Handle Permission Errors

```yaml
- name: Operation with permission check
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    if ! gh api /repos/your-org/repo/collaborators 2>&1 | grep -q "403"; then
      echo "✅ Has required permissions"
      gh api /repos/your-org/repo/collaborators
    else
      echo "❌ Missing permissions - check app configuration"
      exit 1
    fi
```

## Security Best Practices

### Token Exposure Prevention

```yaml
# ❌ BAD: Token exposed in logs
- name: Debug token
  run: echo "Token: ${{ steps.app_token.outputs.token }}"

# ✅ GOOD: Token used securely
- name: Use token
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    gh api /user
```

### Minimize Token Lifetime

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      # Generate token as late as possible
      - uses: actions/checkout@v4

      - name: Prepare environment
        run: |
          # Setup steps that don't need token
          npm install

      # Generate token only when needed
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Use token immediately
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          gh api /orgs/your-org/repos
```

### Audit Token Usage

```yaml
- name: Log operation
  run: |
    echo "::notice::Starting org-level operation with Core App"
    echo "Repository: ${{ github.repository }}"
    echo "Workflow: ${{ github.workflow }}"
    echo "Actor: ${{ github.actor }}"
```

## Troubleshooting

### Common Issues

#### Token Scope Too Narrow

**Symptom**: `404 Not Found` when accessing org resources

**Solution**: Add `owner` parameter to token generation:
```yaml
owner: your-org  # This parameter is required
```

#### Missing Permissions

**Symptom**: `403 Forbidden` errors

**Solution**: Verify Core App has required permissions in app settings

#### Team Query Returns Null

**Symptom**: GraphQL returns `"team": null`

**Solution**: Grant "Members" organization permission to Core App

### Debug Workflow

```yaml
name: Debug Core App Integration
on:
  workflow_dispatch:

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Test token
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          echo "Testing Core App token..."

          echo "✓ Checking rate limits:"
          gh api /rate_limit | jq '.resources.core'

          echo "✓ Testing org access:"
          gh api /orgs/your-org | jq '{name, login}'

          echo "✓ Testing team query:"
          gh api graphql -f query='
          {
            organization(login: "your-org") {
              teams(first: 5) {
                nodes {
                  name
                }
              }
            }
          }' | jq '.data.organization.teams'

          echo "✅ All tests passed"
```

## Performance Optimization

### Reuse Tokens Across Steps

```yaml
jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token once
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Operation 1
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: gh api /orgs/your-org/repos

      - name: Operation 2
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: gh api /orgs/your-org/teams

      - name: Operation 3
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: gh api /orgs/your-org/members
```

**Advantage**: Single token generation for multiple operations

### Parallel Operations

```yaml
strategy:
  matrix:
    operation: [repos, teams, members]
  max-parallel: 3

steps:
  - name: Generate token
    id: app_token
    uses: actions/create-github-app-token@v2
    with:
      app-id: ${{ secrets.CORE_APP_ID }}
      private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
      owner: your-org

  - name: Execute operation
    env:
      GH_TOKEN: ${{ steps.app_token.outputs.token }}
    run: |
      gh api /orgs/your-org/${{ matrix.operation }}
```

## References

- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [GitHub GraphQL API](https://docs.github.com/en/graphql)
- [GitHub Core App Setup](./github-app-setup.md)
