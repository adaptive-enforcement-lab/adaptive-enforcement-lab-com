---
description: >-
  Automate OpenSSF Scorecard monitoring in CI/CD pipelines. Detect score
  regressions, alert on changes, and prevent security practice decay.
tags:
  - scorecard
  - ci-cd
  - automation
---

# CI/CD Integration

Scorecard in CI prevents security practice decay. Run it automatically, detect regressions before they ship, and enforce minimum scores across your organization.

!!! tip "Beyond One-Time Scans"

    Running Scorecard once tells you where you are. Running it continuously tells you when you slip. This guide covers automated monitoring, regression detection, and multi-repo enforcement patterns.

---

## Why Automate Scorecard?

**Problem**: Security practices regress over time.

- Developer accidentally uses workflow-level permissions
- New workflow introduced without SHA pinning
- Branch protection accidentally weakened
- Dependency updates disabled

**Solution**: Automated monitoring catches regressions before merge.

**Real-world impact**:

- **Before**: Token-Permissions score dropped from 10 to 7 over 3 months, unnoticed
- **After**: PR blocked within minutes with "Score regression detected" failure

---

## Basic CI Integration

### Scheduled Weekly Scan

Run Scorecard on a schedule, track results over time:

```yaml
name: Scorecard Monitoring

on:
  schedule:
    - cron: '0 2 * * 1'  # Monday 2 AM UTC
  workflow_dispatch:  # Manual trigger for testing

permissions: read-all  # Scorecard needs read access

jobs:
  scorecard:
    name: Scorecard Analysis
    runs-on: ubuntu-latest
    permissions:
      security-events: write  # Upload SARIF to GitHub
      id-token: write         # OIDC for authenticated results
      contents: read          # Clone repository

    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
        with:
          persist-credentials: false

      - uses: ossf/scorecard-action@v2.4.0  # Must use version tag
        with:
          results_file: results.sarif
          results_format: sarif
          publish_results: true  # Publish to OpenSSF database

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

**What this provides**:

- Weekly scan results viewable in GitHub Security tab
- Historical trend data in OpenSSF database
- SARIF integration with code scanning alerts

**Limitations**:

- No regression detection
- No alerting on score changes
- Results not compared to previous runs

---

## Score Change Detection

### Track Scores Over Time

Store scores in repository, detect changes:

```yaml
name: Scorecard with Change Detection

on:
  schedule:
    - cron: '0 2 * * 1'
  pull_request:
    branches: [main]

permissions: read-all

jobs:
  scorecard:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      id-token: write
      contents: write  # Commit score history
      pull-requests: write  # Comment on PRs

    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
        with:
          persist-credentials: false
          fetch-depth: 0  # Need history for comparison

      - uses: ossf/scorecard-action@v2.4.0
        with:
          results_file: results.sarif
          results_format: sarif
          publish_results: true

      - name: Parse Current Score
        id: current
        run: |
          # Extract overall score from SARIF
          SCORE=$(jq -r '.runs[0].properties.score' results.sarif)
          echo "score=$SCORE" >> "$GITHUB_OUTPUT"

          # Extract individual check scores
          jq -r '.runs[0].tool.driver.rules[] |
            "\(.id):\(.properties.score)"' results.sarif > current-scores.txt

      - name: Compare with Previous
        id: compare
        run: |
          if [[ -f .scorecard/last-score.txt ]]; then
            PREV_SCORE=$(cat .scorecard/last-score.txt)
            CURR_SCORE="${{ steps.current.outputs.score }}"

            echo "previous=$PREV_SCORE" >> "$GITHUB_OUTPUT"
            echo "current=$CURR_SCORE" >> "$GITHUB_OUTPUT"

            # Calculate change
            CHANGE=$(echo "$CURR_SCORE - $PREV_SCORE" | bc)
            echo "change=$CHANGE" >> "$GITHUB_OUTPUT"

            # Detect regression
            if (( $(echo "$CHANGE < 0" | bc -l) )); then
              echo "regression=true" >> "$GITHUB_OUTPUT"
            else
              echo "regression=false" >> "$GITHUB_OUTPUT"
            fi
          else
            echo "regression=false" >> "$GITHUB_OUTPUT"
            mkdir -p .scorecard
          fi

      - name: Store Current Score
        if: github.event_name == 'schedule'
        run: |
          mkdir -p .scorecard
          echo "${{ steps.current.outputs.score }}" > .scorecard/last-score.txt
          cp current-scores.txt .scorecard/current-scores.txt

          # Append to history
          date "+%Y-%m-%d,${{ steps.current.outputs.score }}" >> .scorecard/score-history.csv

      - name: Commit Score History
        if: github.event_name == 'schedule'
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add .scorecard/
          git commit -m "chore: update scorecard history [skip ci]" || true
          git push

      - name: Comment on PR
        if: github.event_name == 'pull_request' && steps.compare.outputs.regression == 'true'
        uses: actions/github-script@v7
        with:
          script: |
            const prev = '${{ steps.compare.outputs.previous }}';
            const curr = '${{ steps.compare.outputs.current }}';
            const change = '${{ steps.compare.outputs.change }}';

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## ⚠️ Scorecard Regression Detected\n\n` +
                    `**Previous Score**: ${prev}\n` +
                    `**Current Score**: ${curr}\n` +
                    `**Change**: ${change}\n\n` +
                    `Review security practice changes before merging.`
            });

      - name: Fail on Regression
        if: steps.compare.outputs.regression == 'true'
        run: |
          echo "::error::Scorecard regression detected"
          exit 1

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
```

**What this provides**:

- Score history tracked in `.scorecard/score-history.csv`
- PR comments when scores regress
- Automated failure on regression
- Trend data for graphing

**Pattern breakdown**:

1. **Extract scores** from SARIF using `jq`
2. **Compare** with previous stored scores
3. **Store** updated scores in repository
4. **Alert** via PR comment if regression detected
5. **Fail** CI if score drops

---

## Alerting Strategies

### Slack Notifications on Regression

Send alerts to team channel when scores drop:

```yaml
      - name: Send Slack Alert
        if: steps.compare.outputs.regression == 'true'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "⚠️ Scorecard Regression Detected",
              "blocks": [
                {
                  "type": "header",
                  "text": {
                    "type": "plain_text",
                    "text": "⚠️ Scorecard Score Dropped"
                  }
                },
                {
                  "type": "section",
                  "fields": [
                    {
                      "type": "mrkdwn",
                      "text": "*Repository*\n${{ github.repository }}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Previous Score*\n${{ steps.compare.outputs.previous }}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Current Score*\n${{ steps.compare.outputs.current }}"
                    },
                    {
                      "type": "mrkdwn",
                      "text": "*Change*\n${{ steps.compare.outputs.change }}"
                    }
                  ]
                },
                {
                  "type": "actions",
                  "elements": [
                    {
                      "type": "button",
                      "text": {
                        "type": "plain_text",
                        "text": "View Results"
                      },
                      "url": "${{ github.server_url }}/${{ github.repository }}/security/code-scanning"
                    }
                  ]
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### Email Notifications

Use GitHub Actions built-in notification system:

```yaml
      - name: Send Email Alert
        if: steps.compare.outputs.regression == 'true'
        uses: dawidd6/action-send-mail@v3
        with:
          server_address: smtp.gmail.com
          server_port: 465
          username: ${{ secrets.EMAIL_USERNAME }}
          password: ${{ secrets.EMAIL_PASSWORD }}
          subject: "[SECURITY] Scorecard Regression: ${{ github.repository }}"
          to: security-team@example.com
          from: GitHub Actions
          body: |
            Scorecard score regression detected in ${{ github.repository }}

            Previous Score: ${{ steps.compare.outputs.previous }}
            Current Score: ${{ steps.compare.outputs.current }}
            Change: ${{ steps.compare.outputs.change }}

            Review: ${{ github.server_url }}/${{ github.repository }}/security/code-scanning
```

### PagerDuty Integration for Critical Regressions

Escalate major regressions:

```yaml
      - name: Calculate Severity
        id: severity
        run: |
          CHANGE="${{ steps.compare.outputs.change }}"

          # Major regression: drop of 1.0 or more
          if (( $(echo "$CHANGE <= -1.0" | bc -l) )); then
            echo "level=critical" >> "$GITHUB_OUTPUT"
          elif (( $(echo "$CHANGE < 0" | bc -l) )); then
            echo "level=warning" >> "$GITHUB_OUTPUT"
          else
            echo "level=info" >> "$GITHUB_OUTPUT"
          fi

      - name: Trigger PagerDuty
        if: steps.severity.outputs.level == 'critical'
        uses: award28/action-pagerduty-trigger@v1
        with:
          integration-key: ${{ secrets.PAGERDUTY_INTEGRATION_KEY }}
          summary: "Critical Scorecard regression in ${{ github.repository }}"
          severity: critical
          source: github-actions
          custom-details: |
            {
              "repository": "${{ github.repository }}",
              "previous_score": "${{ steps.compare.outputs.previous }}",
              "current_score": "${{ steps.compare.outputs.current }}",
              "change": "${{ steps.compare.outputs.change }}"
            }
```

---
