---
title: Token Caching and Rate Limits
description: >-
  Token caching patterns and rate limit management for GitHub App installation tokens. Share tokens across jobs efficiently.
---

## Token Caching Patterns

### Pattern 1: Job Output Caching

Share tokens across dependent jobs.

```yaml
name: Token Caching with Job Outputs

on:
  workflow_dispatch:

jobs:
  token-provider:
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.app_token.outputs.token }}
      repository_id: ${{ steps.app_token.outputs.repository_id }}
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

  consumer-job-1:
    needs: token-provider
    runs-on: ubuntu-latest
    steps:
      - name: Use cached token
        env:
          GH_TOKEN: ${{ needs.token-provider.outputs.token }}
        run: gh api user

  consumer-job-2:
    needs: token-provider
    runs-on: ubuntu-latest
    steps:
      - name: Use same cached token
        env:
          GH_TOKEN: ${{ needs.token-provider.outputs.token }}
        run: gh api repos/adaptive-enforcement-lab/example-repo
```

**Benefits**:

- Single token generation for multiple jobs
- Reduced API calls to GitHub Apps endpoints
- Consistent token across workflow
- Rate limit optimization

**Limitations**:

- Token still expires after 1 hour (from generation time)
- All dependent jobs must complete within token lifetime
- No automatic refresh for cached tokens

### Pattern 2: Artifact-Based Token Caching

For workflows with complex job dependencies.

```yaml
name: Artifact-Based Token Caching

on:
  workflow_dispatch:

jobs:
  generate-and-cache:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Cache token in artifact
        run: |
          mkdir -p .tokens
          echo "${{ steps.app_token.outputs.token }}" > .tokens/gh_token
          echo "::add-mask::$(cat .tokens/gh_token)"

      - name: Upload token artifact
        uses: actions/upload-artifact@v4
        with:
          name: github-token
          path: .tokens/gh_token
          retention-days: 1

  use-cached-token:
    needs: generate-and-cache
    runs-on: ubuntu-latest
    strategy:
      matrix:
        operation: [check-1, check-2, check-3]
    steps:
      - name: Download token artifact
        uses: actions/download-artifact@v4
        with:
          name: github-token
          path: .tokens

      - name: Load and mask token
        id: load_token
        run: |
          TOKEN=$(cat .tokens/gh_token)
          echo "::add-mask::$TOKEN"
          echo "token=$TOKEN" >> $GITHUB_OUTPUT

      - name: Use token
        env:
          GH_TOKEN: ${{ steps.load_token.outputs.token }}
        run: |
          echo "Running ${{ matrix.operation }}"
          gh api user --jq .login
```

!!! danger "Token Security in Artifacts"

    - Always mask tokens with `::add-mask::`
    - Set short retention periods (1 day maximum)
    - Use artifact encryption if available
    - Delete artifacts after workflow completes

### Pattern 3: Environment Variable Caching

For reusable workflows and composite actions.

```yaml
name: Environment Variable Token Caching

on:
  workflow_dispatch:

env:
  # Generate once, use throughout workflow
  TOKEN_CACHE_ENABLED: true

jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.app_token.outputs.token }}
    steps:
      - name: Generate cached token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

  operation-1:
    needs: setup
    runs-on: ubuntu-latest
    env:
      GH_TOKEN: ${{ needs.setup.outputs.token }}
    steps:
      - run: gh api repos/adaptive-enforcement-lab/repo-1

  operation-2:
    needs: setup
    runs-on: ubuntu-latest
    env:
      GH_TOKEN: ${{ needs.setup.outputs.token }}
    steps:
      - run: gh api repos/adaptive-enforcement-lab/repo-2

  operation-3:
    needs: setup
    runs-on: ubuntu-latest
    env:
      GH_TOKEN: ${{ needs.setup.outputs.token }}
    steps:
      - run: gh api repos/adaptive-enforcement-lab/repo-3
```

## Rate Limit Management

### Understanding Rate Limits

Installation tokens share organization-level rate limits:

- **REST API**: 5,000 requests/hour per installation
- **GraphQL API**: 5,000 points/hour per installation
- **Search API**: 30 requests/minute per installation

```yaml
name: Rate Limit Monitoring

on:
  workflow_dispatch:

jobs:
  monitor-rate-limits:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Check rate limit before operations
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          echo "## Rate Limit Status" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          gh api /rate_limit --jq '{
            core: {
              limit: .resources.core.limit,
              remaining: .resources.core.remaining,
              reset: (.resources.core.reset | strftime("%Y-%m-%d %H:%M:%S"))
            },
            search: {
              limit: .resources.search.limit,
              remaining: .resources.search.remaining,
              reset: (.resources.search.reset | strftime("%Y-%m-%d %H:%M:%S"))
            },
            graphql: {
              limit: .resources.graphql.limit,
              remaining: .resources.graphql.remaining,
              reset: (.resources.graphql.reset | strftime("%Y-%m-%d %H:%M:%S"))
            }
          }' | tee -a $GITHUB_STEP_SUMMARY

      - name: Perform operations with rate limit checks
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          check_rate_limit() {
            REMAINING=$(gh api /rate_limit --jq '.resources.core.remaining')
            RESET_TIME=$(gh api /rate_limit --jq '.resources.core.reset')

            if [ "$REMAINING" -lt 100 ]; then
              CURRENT_TIME=$(date +%s)
              WAIT_TIME=$((RESET_TIME - CURRENT_TIME))

              echo "::warning::Rate limit low ($REMAINING remaining)"
              echo "::notice::Waiting $((WAIT_TIME / 60)) minutes for rate limit reset"

              sleep $WAIT_TIME
            fi
          }

          # Perform operations with rate limit awareness
          for i in {1..100}; do
            # Check rate limit every 10 iterations
            if [ $((i % 10)) -eq 0 ]; then
              check_rate_limit
            fi

            gh api repos/adaptive-enforcement-lab/example-repo
          done
```

### Rate Limit Optimization

```yaml
name: Rate Limit Optimization

on:
  workflow_dispatch:

jobs:
  optimized-operations:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Batch API calls to reduce rate limit usage
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          # ❌ BAD: 100 individual API calls
          # for repo in $(gh repo list adaptive-enforcement-lab --limit 100 --json name --jq '.[].name'); do
          #   gh api repos/adaptive-enforcement-lab/$repo
          # done

          # ✅ GOOD: Single paginated API call
          gh api /orgs/adaptive-enforcement-lab/repos \
            --paginate \
            --jq '.[] | {name: .name, stars: .stargazers_count}'

      - name: Use GraphQL for complex queries (better rate limit efficiency)
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          # GraphQL query costs fewer points than equivalent REST calls
          gh api graphql -f query='
          query {
            organization(login: "adaptive-enforcement-lab") {
              repositories(first: 100) {
                nodes {
                  name
                  stargazerCount
                  issues(first: 10, states: OPEN) {
                    totalCount
                    nodes {
                      title
                      createdAt
                    }
                  }
                }
              }
            }
          }' --jq '.data.organization.repositories.nodes'
```
