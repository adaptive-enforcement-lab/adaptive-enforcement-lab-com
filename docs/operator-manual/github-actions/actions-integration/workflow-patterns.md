---
title: Workflow Patterns
description: >-
  Common workflow patterns for GitHub Actions integration including team
  repository queries, cross-repo file operations, PR creation, and matrix
  strategies.
---

# Common Workflow Patterns

## Pattern 1: Query Team Repositories

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

## Pattern 2: Cross-Repository File Operations

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

## Pattern 3: Create Pull Requests

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

## Pattern 4: Matrix Strategy with Dynamic Repositories

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
