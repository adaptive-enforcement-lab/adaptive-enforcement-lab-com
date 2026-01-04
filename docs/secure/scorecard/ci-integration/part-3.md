---
title: Enforcement Patterns
description: >-
  Enforce minimum Scorecard thresholds in CI pipelines to prevent security regressions and maintain continuous compliance with GitHub Actions.
---
# Enforcement Patterns

!!! tip "Key Insight"
    Enforcement patterns prevent security regressions in CI pipelines.

## Enforcement Patterns

### Minimum Score Requirements

Block PRs that drop score below threshold:

```yaml
      - name: Enforce Minimum Score
        run: |
          MIN_SCORE=8.0
          CURRENT_SCORE="${{ steps.current.outputs.score }}"

          if (( $(echo "$CURRENT_SCORE < $MIN_SCORE" | bc -l) )); then
            echo "::error::Scorecard score $CURRENT_SCORE below minimum $MIN_SCORE"
            exit 1
          fi
```

### Per-Check Enforcement

Require specific checks to pass:

```yaml
      - name: Enforce Critical Checks
        run: |
          # Extract critical check scores
          TOKEN_PERMS=$(jq -r '
            .runs[0].tool.driver.rules[] |
            select(.id == "Token-Permissions") |
            .properties.score
          ' results.sarif)

          SIGNED_RELEASES=$(jq -r '
            .runs[0].tool.driver.rules[] |
            select(.id == "Signed-Releases") |
            .properties.score
          ' results.sarif)

          # Enforce minimums
          if (( $(echo "$TOKEN_PERMS < 10" | bc -l) )); then
            echo "::error::Token-Permissions must be 10/10 (current: $TOKEN_PERMS)"
            exit 1
          fi

          if (( $(echo "$SIGNED_RELEASES < 9" | bc -l) )); then
            echo "::error::Signed-Releases must be 9+/10 (current: $SIGNED_RELEASES)"
            exit 1
          fi
```

### Exemption Workflow

Allow documented exemptions:

```yaml
      - name: Check Exemptions
        id: exemption
        run: |
          if [[ -f .scorecard/exemptions.json ]]; then
            # Check if current repo/branch is exempted
            EXEMPT=$(jq -r '
              .exemptions[] |
              select(.repository == "${{ github.repository }}") |
              select(.branch == "${{ github.ref_name }}") |
              .exempt
            ' .scorecard/exemptions.json)

            if [[ "$EXEMPT" == "true" ]]; then
              echo "exempt=true" >> "$GITHUB_OUTPUT"
            else
              echo "exempt=false" >> "$GITHUB_OUTPUT"
            fi
          else
            echo "exempt=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Enforce or Warn
        run: |
          if [[ "${{ steps.exemption.outputs.exempt }}" == "true" ]]; then
            echo "::warning::Score below threshold but repository is exempted"
          else
            if (( $(echo "${{ steps.current.outputs.score }} < 8.0" | bc -l) )); then
              echo "::error::Score below threshold and no exemption found"
              exit 1
            fi
          fi
```

**Exemption file format** (`.scorecard/exemptions.json`):

```json
{
  "exemptions": [
    {
      "repository": "org/experimental-repo",
      "branch": "main",
      "exempt": true,
      "reason": "Experimental project, security hardening planned for Q2",
      "expires": "2025-06-30",
      "approvedBy": "security-team"
    }
  ]
}
```

---

## Performance Optimization

### Caching Scorecard Data

Reduce API calls:

```yaml
      - name: Cache Scorecard
        uses: actions/cache@v4
        with:
          path: |
            ~/.cache/scorecard
          key: scorecard-${{ github.repository }}-${{ github.sha }}
          restore-keys: |
            scorecard-${{ github.repository }}-
```

### Incremental Scanning

Only scan changed workflows:

```yaml
      - name: Detect Workflow Changes
        id: changes
        run: |
          if git diff --name-only origin/main...HEAD | grep -q '^\.github/workflows/'; then
            echo "workflows_changed=true" >> "$GITHUB_OUTPUT"
          else
            echo "workflows_changed=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Run Scorecard
        if: steps.changes.outputs.workflows_changed == 'true'
        uses: ossf/scorecard-action@v2.4.0
        with:
          results_file: results.sarif
          results_format: sarif
```

**Trade-off**: Faster, but may miss configuration changes outside `.github/workflows/`.

---

## Troubleshooting

### "No previous score found"

**Symptom**: First run fails with "no comparison data"

**Fix**: Initialize score history:

```bash
mkdir -p .scorecard
echo "0" > .scorecard/last-score.txt
echo "date,score" > .scorecard/score-history.csv
git add .scorecard/
git commit -m "chore: initialize scorecard tracking"
```

### "Permission denied when committing scores"

**Symptom**: Workflow can't commit to repository

**Fix**: Grant `contents: write` permission and use `GITHUB_TOKEN`:

```yaml
permissions:
  contents: write

steps:
  - name: Commit Results
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    run: |
      git config user.name "github-actions[bot]"
      git config user.email "github-actions[bot]@users.noreply.github.com"
      git add .scorecard/
      git commit -m "chore: update scores"
      git push
```

### "SARIF upload fails"

**Symptom**: `upload-sarif` step fails with permission error

**Fix**: Ensure `security-events: write` permission:

```yaml
permissions:
  security-events: write
```

### "Matrix job exceeds runner limit"

**Symptom**: Multi-repo scan fails with "too many jobs"

**Fix**: Batch repositories:

```yaml
strategy:
  matrix:
    batch: [0, 1, 2, 3]  # 4 batches of repos
  fail-fast: false

steps:
  - name: Get Batch
    run: |
      BATCH_SIZE=50
      START=$((BATCH_SIZE * ${{ matrix.batch }}))

      jq -r ".[$START:$START+$BATCH_SIZE][]" repos.json > batch-repos.txt
```

---

## Monitoring Best Practices

### What to Monitor

**Critical metrics**:

1. **Overall score trend**: Is it improving or declining?
2. **Check-specific scores**: Which checks are problematic?
3. **Regression frequency**: How often do scores drop?
4. **Time to remediation**: How fast are regressions fixed?

**Dashboard example**:

```text
Repository: adaptive-enforcement-lab/repo-audit
Last 4 weeks:
  Week 1: 8.5
  Week 2: 8.7 (+0.2)
  Week 3: 7.9 (-0.8) ← Regression
  Week 4: 8.8 (+0.9) ← Fixed

Most Improved: Token-Permissions (7 → 10)
Most Problematic: Fuzzing (stuck at 0)
```

### Alert Thresholds

**Recommended thresholds**:

| Event | Threshold | Action |
|-------|-----------|--------|
| Any regression | < 0 | Slack notification |
| Minor regression | -0.5 to -1.0 | Block PR merge |
| Major regression | < -1.0 | PagerDuty alert |
| Critical check fails | Token-Permissions < 10 | Block PR immediately |

### Review Cadence

**Scheduled reviews**:

- **Weekly**: Review automated scan results
- **Monthly**: Analyze trends, identify patterns
- **Quarterly**: Adjust thresholds, update exemptions

---

## Related Patterns

- [Scorecard Workflow Examples](../scorecard-workflow-examples.md) - Basic workflow implementation
- [Score Progression](../score-progression.md) - Achieving higher scores systematically
- [False Positives Guide](../false-positives.md) - Handling false positive alerts
- [Decision Framework](../decision-framework.md) - When to deviate from recommendations

---

*Scorecard automation turns security practices from aspirational to enforced. Set it up once, prevent regressions forever. The goal isn't a perfect score: it's continuous improvement and no backsliding.*
