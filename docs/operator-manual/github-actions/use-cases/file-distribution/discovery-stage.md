---
title: "Stage 1: Discovery"
description: >-
  Query organization for target repositories using GraphQL.
---

# Stage 1: Repository Discovery

Query repositories via GraphQL to determine distribution targets.

## Implementation

```yaml
jobs:
  discover:
    name: Discover target repositories
    runs-on: ubuntu-latest
    outputs:
      repositories: ${{ steps.query.outputs.repos }}
      count: ${{ steps.query.outputs.count }}
    steps:
      - name: Generate authentication token
        id: auth
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Query team repositories
        id: query
        env:
          GH_TOKEN: ${{ steps.auth.outputs.token }}
        run: |
          REPOS=$(gh api graphql -f query='
          {
            organization(login: "your-org") {
              team(slug: "target-team") {
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
          }' --jq '.data.organization.team.repositories.nodes |
            map({name: .name, default_branch: .defaultBranchRef.name})')

          echo "repos=$REPOS" >> $GITHUB_OUTPUT

          COUNT=$(echo "$REPOS" | jq 'length')
          echo "count=$COUNT" >> $GITHUB_OUTPUT
          echo "Found $COUNT repositories"
```

## Key Features

- GraphQL query scopes to specific team
- Returns repository names and default branch
- Outputs JSON array for matrix strategy

## Pagination Handling

GraphQL queries have a **100-item limit** per request. Without pagination, repositories beyond the first 100 are silently ignored.

!!! danger "The 100-Repository Trap"

    If your team has 105 repositories and you query with `first: 100`, only 100 are returned.
    The workflow completes successfully—but 5 repositories never receive updates.
    This is a silent failure that's easy to miss.

### Fail-Fast Approach

For teams unlikely to exceed 100 repositories, fail loudly when the limit is reached:

```bash
#!/bin/bash
# fetch-repos.sh - Fail-fast pagination guard

RESPONSE=$(gh api graphql -f query='
{
  organization(login: "your-org") {
    team(slug: "target-team") {
      repositories(first: 100) {
        totalCount
        nodes {
          name
          defaultBranchRef {
            name
          }
        }
      }
    }
  }
}')

TOTAL=$(echo "$RESPONSE" | jq '.data.organization.team.repositories.totalCount')
RETURNED=$(echo "$RESPONSE" | jq '.data.organization.team.repositories.nodes | length')

if [ "$TOTAL" -gt "$RETURNED" ]; then
  echo "::error::Repository count ($TOTAL) exceeds query limit ($RETURNED). Implement pagination."
  exit 1
fi

REPOS=$(echo "$RESPONSE" | jq '.data.organization.team.repositories.nodes |
  map({name: .name, default_branch: .defaultBranchRef.name})')

echo "repos=$REPOS" >> "$GITHUB_OUTPUT"
echo "count=$RETURNED" >> "$GITHUB_OUTPUT"
```

The `totalCount` field reveals how many repositories exist, even when `nodes` is limited. Compare them to detect truncation.

### Full Pagination

For larger organizations, use the `--paginate` flag:

```bash
REPOS=$(gh api graphql --paginate -f query='
{
  organization(login: "your-org") {
    team(slug: "target-team") {
      repositories(first: 100) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          name
          defaultBranchRef {
            name
          }
        }
      }
    }
  }
}' --jq '.data.organization.team.repositories.nodes |
  map({name: .name, default_branch: .defaultBranchRef.name})')
```

The `--paginate` flag automatically follows `pageInfo.hasNextPage` and aggregates results.

### Choosing an Approach

| Team Size | Approach | Rationale |
| ----------- | ---------- | ----------- |
| < 50 repos | Simple query | No risk of hitting limit |
| 50-100 repos | Fail-fast guard | Catch limit before it's a problem |
| > 100 repos | Full pagination | Required for completeness |

---

## Related

- [Stage 2: Distribution](distribution-stage.md) - Process discovered repositories
- [Workflow Configuration](workflow-config.md) - Triggers and scheduled runs
- [Architecture](architecture.md) - Three-stage workflow overview

---

## References

- [GitHub GraphQL API](https://docs.github.com/en/graphql) - Query syntax and explorer
- [gh api graphql](https://cli.github.com/manual/gh_api) - CLI reference for GraphQL queries
- [GraphQL Pagination](https://docs.github.com/en/graphql/guides/using-pagination-in-the-graphql-api) - Official pagination guide
