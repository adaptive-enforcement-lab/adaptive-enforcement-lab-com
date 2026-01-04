---
title: Badge Integration
description: >-
  Display OpenSSF Scorecard badges in README files to communicate security posture and track improvement trends across your organization.
---
# Badge Integration

!!! tip "Key Insight"
    Scorecard badges provide transparency into project security posture.

## Badge Integration

### Display Current Score

Add Scorecard badge to README:

```markdown
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/owner/repo/badge)](https://scorecard.dev/viewer/?uri=github.com/owner/repo)
```

**Result**:

![Badge Example](https://img.shields.io/badge/Scorecard-8.5-orange?logo=security&logoColor=white)

### Custom Score Badge

Generate custom badge from stored scores:

```yaml
      - name: Generate Badge
        run: |
          SCORE="${{ steps.current.outputs.score }}"

          # Determine color based on score
          if (( $(echo "$SCORE >= 9.0" | bc -l) )); then
            COLOR="brightgreen"
          elif (( $(echo "$SCORE >= 8.0" | bc -l) )); then
            COLOR="green"
          elif (( $(echo "$SCORE >= 7.0" | bc -l) )); then
            COLOR="yellow"
          elif (( $(echo "$SCORE >= 6.0" | bc -l) )); then
            COLOR="orange"
          else
            COLOR="red"
          fi

          # Create badge JSON
          cat > .scorecard/badge.json <<EOF
          {
            "schemaVersion": 1,
            "label": "Scorecard",
            "message": "$SCORE",
            "color": "$COLOR"
          }
          EOF

      - name: Upload Badge
        uses: exuanbo/actions-deploy-gist@v1
        with:
          token: ${{ secrets.GIST_TOKEN }}
          gist_id: your-badge-gist-id
          file_path: .scorecard/badge.json
```

**Use in README**:

```markdown
![Scorecard](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/user/gist-id/raw/badge.json)
```

---

## Multi-Repo Monitoring

### Organization-Wide Scorecard Dashboard

**Pattern**: Central workflow monitors all repositories.

#### 1. Discovery Workflow

Find all repositories in organization:

```yaml
name: Scorecard Discovery

on:
  schedule:
    - cron: '0 1 * * 1'  # Monday 1 AM
  workflow_dispatch:

permissions:
  contents: write

jobs:
  discover:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - name: Get Organization Repos
        uses: actions/github-script@v7
        with:
          script: |
            const repos = await github.paginate(
              github.rest.repos.listForOrg,
              { org: context.repo.owner }
            );

            const repoList = repos
              .filter(r => !r.archived && !r.fork)  // Skip archived/forks
              .map(r => r.full_name);

            const fs = require('fs');
            fs.writeFileSync('repos.json', JSON.stringify(repoList, null, 2));

      - uses: actions/upload-artifact@v4
        with:
          name: repo-list
          path: repos.json
```

#### 2. Distribution Workflow

Scan each repository:

```yaml
  scan:
    needs: discover
    runs-on: ubuntu-latest
    strategy:
      matrix:
        # Read from artifact, max 256 repos at once
        repo: ${{ fromJson(needs.discover.outputs.repos) }}
      fail-fast: false

    steps:
      - name: Generate App Token
        id: token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.SCORECARD_APP_ID }}
          private-key: ${{ secrets.SCORECARD_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Checkout Target Repo
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
        with:
          repository: ${{ matrix.repo }}
          token: ${{ steps.token.outputs.token }}
          persist-credentials: false

      - uses: ossf/scorecard-action@v2.4.0
        with:
          results_file: results.sarif
          results_format: sarif
          publish_results: true

      - name: Extract Score
        id: score
        run: |
          SCORE=$(jq -r '.runs[0].properties.score' results.sarif)
          echo "score=$SCORE" >> "$GITHUB_OUTPUT"

          # Extract check details
          jq -r '.runs[0].tool.driver.rules[] |
            {name: .id, score: .properties.score, reason: .fullDescription.text}' \
            results.sarif > check-details.json

      - name: Store Results
        run: |
          mkdir -p results
          cat > "results/${{ matrix.repo }}.json" <<EOF
          {
            "repository": "${{ matrix.repo }}",
            "score": "${{ steps.score.outputs.score }}",
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "checks": $(cat check-details.json)
          }
          EOF

      - uses: actions/upload-artifact@v4
        with:
          name: scorecard-${{ hashFiles(matrix.repo) }}
          path: results/
```

#### 3. Summary Workflow

Aggregate results, generate dashboard:

```yaml
  summary:
    needs: scan
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: actions/download-artifact@v4
        with:
          pattern: scorecard-*
          path: all-results/

      - name: Aggregate Results
        run: |
          # Combine all JSON files
          jq -s '.' all-results/*/*.json > scorecard-summary.json

          # Calculate statistics
          jq -r '
            .[] |
            select(.score != null) |
            .score
          ' scorecard-summary.json |
          awk '{
            sum += $1
            count++
            if ($1 < min || NR == 1) min = $1
            if ($1 > max || NR == 1) max = $1
          }
          END {
            print "Average:", sum/count
            print "Min:", min
            print "Max:", max
          }' > statistics.txt

      - name: Generate Dashboard
        run: |
          cat > dashboard.md <<'EOF'
          # Organization Scorecard Dashboard

          **Last Updated**: $(date -u +"%Y-%m-%d %H:%M UTC")

          ## Summary Statistics

          $(cat statistics.txt)

          ## Repository Scores

          | Repository | Score | Status |
          |------------|-------|--------|
          EOF

          jq -r '
            sort_by(.score) |
            reverse |
            .[] |
            "| \(.repository) | \(.score) | " +
            if (.score >= 9.0) then "🟢 Excellent"
            elif (.score >= 8.0) then "🟡 Good"
            elif (.score >= 7.0) then "🟠 Fair"
            else "🔴 Needs Work"
            end + " |"
          ' scorecard-summary.json >> dashboard.md

          echo "" >> dashboard.md
          echo "---" >> dashboard.md
          echo "" >> dashboard.md
          echo "**Repositories Below Threshold (< 8.0)**:" >> dashboard.md
          echo "" >> dashboard.md

          jq -r '
            .[] |
            select(.score < 8.0) |
            "- **\(.repository)**: \(.score)"
          ' scorecard-summary.json >> dashboard.md

      - name: Commit Dashboard
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add dashboard.md scorecard-summary.json
          git commit -m "chore: update scorecard dashboard [skip ci]"
          git push

      - name: Send Alerts
        run: |
          # Identify repos below threshold
          LOW_REPOS=$(jq -r '
            .[] |
            select(.score < 8.0) |
            .repository
          ' scorecard-summary.json)

          if [[ -n "$LOW_REPOS" ]]; then
            echo "::warning::Repositories below threshold: $LOW_REPOS"
          fi
```

**Pattern breakdown**:

1. **Discovery**: Enumerate all org repositories
2. **Distribution**: Matrix job scans each repository
3. **Summary**: Aggregate results, generate dashboard

**GitHub App requirements**:

- `contents: read` - Read all repositories
- `security-events: write` - Upload SARIF results

---
