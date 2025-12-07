---
title: "Stage 3: Summary"
description: >-
  Aggregate results and display PR links.
---

# Stage 3: Result Summary

Aggregate results and display PR links.

!!! tip "Always Run Summary"
    Use `if: always()` so the summary runs even when distribution jobs fail. Users need visibility into failures.

## Implementation

```yaml
summary:
  name: Distribution summary
  needs: [discover, distribute]
  runs-on: ubuntu-latest
  if: always()
  steps:
    - name: Generate authentication token
      id: auth
      uses: actions/create-github-app-token@v2
      with:
        app-id: ${{ secrets.CORE_APP_ID }}
        private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
        owner: your-org

    - name: Generate summary
      env:
        GH_TOKEN: ${{ steps.auth.outputs.token }}
      run: |
        echo "## Distribution Complete" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "**Repositories processed:** ${{ needs.discover.outputs.count }}" >> $GITHUB_STEP_SUMMARY
        echo "**Trigger:** ${{ github.event_name }}" >> $GITHUB_STEP_SUMMARY
        echo "**Commit:** ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY

        # Extract PR URLs from workflow logs
        echo "### Pull Requests" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY

        PR_URLS=$(gh run view ${{ github.run_id }} --log 2>&1 |
          grep -o 'https://github.com/your-org/[^/]*/pull/[0-9]*' |
          sort -u || true)

        if [ -n "$PR_URLS" ]; then
          while IFS= read -r pr_url; do
            repo_name=$(echo "$pr_url" | sed 's|.*/\([^/]*\)/pull/.*|\1|')
            echo "- [$repo_name]($pr_url)" >> $GITHUB_STEP_SUMMARY
          done <<< "$PR_URLS"
        else
          echo "*No new pull requests created*" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "Existing PRs may have been updated, or files are already current" >> $GITHUB_STEP_SUMMARY
        fi
```

## Key Features

- `if: always()` runs even if distribution jobs fail
- Extracts PR URLs from workflow logs
- Provides clickable summary of results

## Example Output

```markdown
## Distribution Complete

**Repositories processed:** 42
**Trigger:** push
**Commit:** abc123def

### Pull Requests

- [repository-1](https://github.com/org/repository-1/pull/15)
- [repository-2](https://github.com/org/repository-2/pull/8)
- [repository-3](https://github.com/org/repository-3/pull/23)

*No new pull requests created for 39 repositories*
*Existing PRs were updated or files are already current*
```
