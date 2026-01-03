---
title: Real-World Use Cases
description: >-
  Real-world use cases for GitHub App installation tokens including dependency updates, health monitoring, issue triage, and release coordination.
---

# Real-World Use Cases

## Use Case 1: Centralized Dependency Updates

Update dependencies across all repositories from a central workflow.

```yaml
name: Organization Dependency Update

on:
  workflow_dispatch:
    inputs:
      package:
        description: 'Package to update'
        required: true
      version:
        description: 'Target version'
        required: true

jobs:
  update-dependencies:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repository:
          - frontend-app
          - backend-api
          - admin-dashboard
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          repository: adaptive-enforcement-lab/${{ matrix.repository }}
          token: ${{ steps.app_token.outputs.token }}

      - name: Update package
        run: |
          if [ ! -f "package.json" ]; then
            echo "No package.json found, skipping"
            exit 0
          fi

          npm install ${{ github.event.inputs.package }}@${{ github.event.inputs.version }}

          if git diff --quiet package.json package-lock.json; then
            echo "No changes needed"
            exit 0
          fi

          # Create branch and PR
          BRANCH="deps/update-${{ github.event.inputs.package }}-${{ github.event.inputs.version }}"
          git checkout -b $BRANCH

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git add package.json package-lock.json
          git commit -m "deps: update ${{ github.event.inputs.package }} to ${{ github.event.inputs.version }}"
          git push origin $BRANCH

      - name: Create pull request
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          gh pr create \
            --repo adaptive-enforcement-lab/${{ matrix.repository }} \
            --title "deps: update ${{ github.event.inputs.package }} to ${{ github.event.inputs.version }}" \
            --body "$(cat <<'EOF'
## Dependency Update

Automated update of ${{ github.event.inputs.package }} to version ${{ github.event.inputs.version }}.

### Changes
- Updated ${{ github.event.inputs.package }} from previous version to ${{ github.event.inputs.version }}

### Testing
- [ ] Verify build passes
- [ ] Run test suite
- [ ] Check for breaking changes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)" \
            --base main \
            --head deps/update-${{ github.event.inputs.package }}-${{ github.event.inputs.version }}
```

## Use Case 2: Repository Health Monitoring

Monitor repository health metrics across your organization.

```yaml
name: Repository Health Dashboard

on:
  schedule:
    - cron: '0 8 * * *'  # Daily at 8 AM
  workflow_dispatch:

jobs:
  collect-metrics:
    runs-on: ubuntu-latest
    steps:
      - name: Generate org-scoped token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Collect repository metrics
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          echo "# Repository Health Dashboard" >> $GITHUB_STEP_SUMMARY
          echo "Generated: $(date -u '+%Y-%m-%d %H:%M UTC')" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY

          # Get all repositories
          REPOS=$(gh repo list adaptive-enforcement-lab \
            --limit 100 \
            --json nameWithOwner \
            --jq '.[].nameWithOwner')

          echo "## Metrics" >> $GITHUB_STEP_SUMMARY
          echo "| Repository | Open PRs | Open Issues | Last Update | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-----------|----------|-------------|-------------|--------|" >> $GITHUB_STEP_SUMMARY

          for repo in $REPOS; do
            # Get repository data
            DATA=$(gh api repos/$repo --jq '{
              open_prs: .open_issues_count,
              updated: .updated_at,
              archived: .archived
            }')

            OPEN_PRS=$(gh pr list --repo $repo --state open --json number --jq length)
            OPEN_ISSUES=$(gh issue list --repo $repo --state open --json number --jq length)
            UPDATED=$(echo $DATA | jq -r .updated | cut -d'T' -f1)
            ARCHIVED=$(echo $DATA | jq -r .archived)

            if [ "$ARCHIVED" = "true" ]; then
              STATUS="📦 Archived"
            else
              STATUS="✅ Active"
            fi

            echo "| $repo | $OPEN_PRS | $OPEN_ISSUES | $UPDATED | $STATUS |" >> $GITHUB_STEP_SUMMARY
          done

      - name: Alert on stale repositories
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "## ⚠️ Stale Repositories (>90 days)" >> $GITHUB_STEP_SUMMARY

          STALE=$(gh repo list adaptive-enforcement-lab \
            --limit 100 \
            --json nameWithOwner,updatedAt \
            --jq --arg cutoff "$(date -u -d '90 days ago' '+%Y-%m-%d')" \
              '.[] | select(.updatedAt < $cutoff) | .nameWithOwner')

          if [ -z "$STALE" ]; then
            echo "No stale repositories found" >> $GITHUB_STEP_SUMMARY
          else
            echo "$STALE" | while read repo; do
              echo "- $repo" >> $GITHUB_STEP_SUMMARY
            done
          fi
```

## Use Case 3: Automated Issue Triage

Triage issues across all repositories.

```yaml
name: Organization Issue Triage

on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

jobs:
  triage:
    runs-on: ubuntu-latest
    steps:
      - name: Generate org-scoped token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Find untriaged issues
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          # Search for issues without labels across organization
          gh issue list \
            --search "org:adaptive-enforcement-lab is:open no:label" \
            --json repository,number,title,url \
            --jq '.[] | "\(.repository.nameWithOwner)#\(.number): \(.title)"' \
            > untriaged.txt

          if [ ! -s untriaged.txt ]; then
            echo "No untriaged issues found"
            exit 0
          fi

          echo "## Untriaged Issues" >> $GITHUB_STEP_SUMMARY
          cat untriaged.txt >> $GITHUB_STEP_SUMMARY

      - name: Apply triage labels
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          gh issue list \
            --search "org:adaptive-enforcement-lab is:open no:label" \
            --json repository,number,title,body \
            --jq -r '.[] | "\(.repository.nameWithOwner)|\(.number)|\(.title)|\(.body)"' \
            | while IFS='|' read -r repo number title body; do

            # Simple keyword-based labeling
            labels=""

            if echo "$title $body" | grep -qi "bug\|error\|crash"; then
              labels="bug"
            elif echo "$title $body" | grep -qi "feature\|enhancement"; then
              labels="enhancement"
            elif echo "$title $body" | grep -qi "documentation\|docs"; then
              labels="documentation"
            else
              labels="triage"
            fi

            # Apply label
            gh issue edit $number \
              --repo $repo \
              --add-label "$labels"

            echo "Labeled $repo#$number as $labels"
          done
```

## Use Case 4: Cross-Repository Release Coordination

Coordinate releases across multiple microservices.

```yaml
name: Coordinated Release

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version'
        required: true
      services:
        description: 'Services to release (JSON array)'
        required: true
        default: '["frontend-app", "backend-api", "infrastructure"]'

jobs:
  release:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: ${{ fromJson(github.event.inputs.services) }}
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Create release
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          # Generate release notes
          NOTES=$(gh api repos/adaptive-enforcement-lab/${{ matrix.service }}/releases/generate-notes \
            --method POST \
            --field tag_name="v${{ github.event.inputs.version }}" \
            --jq .body)

          # Create release
          gh release create \
            "v${{ github.event.inputs.version }}" \
            --repo adaptive-enforcement-lab/${{ matrix.service }} \
            --title "Release v${{ github.event.inputs.version }}" \
            --notes "$NOTES"

          echo "Created release for ${{ matrix.service }}"

      - name: Trigger deployment
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          gh workflow run deploy.yml \
            --repo adaptive-enforcement-lab/${{ matrix.service }} \
            --ref "v${{ github.event.inputs.version }}"
```
