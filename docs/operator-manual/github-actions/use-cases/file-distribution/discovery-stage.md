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

For organizations with many repositories, implement pagination:

```bash
# In discovery script
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

# Add pagination guard
COUNT=$(echo "$REPOS" | jq 'length')
if [ "$COUNT" -ge 100 ]; then
  echo "WARNING: Repository count at limit, some repos may be missing"
  echo "Implement proper pagination handling"
fi
```
