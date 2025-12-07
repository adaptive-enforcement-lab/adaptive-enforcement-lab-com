---
title: Monitoring
description: >-
  Workflow summaries and metrics collection.
---

# Monitoring and Observability

!!! abstract "Visibility Matters"
    Summaries, badges, and notifications turn automation from a black box into a transparent process.

## Workflow Summary Format

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

## Metrics Collection

```yaml
- name: Collect metrics
  run: |
    echo "repos_processed=${{ needs.discover.outputs.count }}" >> metrics.txt
    echo "prs_created=$(gh pr list --search 'author:app/automation' --json number | jq 'length')" >> metrics.txt
```

## Status Badges

Add workflow status badge to README:

```markdown
[![Distribution Status](https://github.com/your-org/central-repo/actions/workflows/distribute.yml/badge.svg)](https://github.com/your-org/central-repo/actions/workflows/distribute.yml)
```

## Detailed Job Summary

```yaml
- name: Generate detailed summary
  run: |
    echo "## Distribution Report" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Repository | Status | PR |" >> $GITHUB_STEP_SUMMARY
    echo "|------------|--------|-----|" >> $GITHUB_STEP_SUMMARY

    # Parse job results and generate table
    for repo in $(echo '${{ needs.discover.outputs.repositories }}' | jq -r '.[].name'); do
      # Check if PR exists
      PR=$(gh pr list --repo your-org/$repo --head automated-update --json url --jq '.[0].url // "N/A"')
      echo "| $repo | :white_check_mark: | $PR |" >> $GITHUB_STEP_SUMMARY
    done
```

## Slack Notifications

```yaml
- name: Send Slack notification
  if: always()
  uses: slackapi/slack-github-action@v1
  with:
    payload: |
      {
        "text": "Distribution workflow ${{ job.status }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Distribution Complete*\n• Repos: ${{ needs.discover.outputs.count }}\n• Status: ${{ needs.distribute.result }}"
            }
          }
        ]
      }
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## Historical Tracking

Store metrics in repository for historical tracking:

```yaml
- name: Update metrics history
  run: |
    DATE=$(date +%Y-%m-%d)
    echo "$DATE,${{ needs.discover.outputs.count }},${{ needs.distribute.result }}" >> metrics/distribution-history.csv
    git add metrics/distribution-history.csv
    git commit -m "chore: update distribution metrics"
    git push
```
