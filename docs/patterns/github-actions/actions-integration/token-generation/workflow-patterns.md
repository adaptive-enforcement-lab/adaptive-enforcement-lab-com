---
title: Cross-Repository Workflow Patterns
description: >-
  Patterns for cross-repository automation including discovery and distribution, synchronized updates, and parallel operations using GitHub App installation tokens.
---

# Cross-Repository Workflow Patterns

## Pattern 1: Discovery and Distribution

Discover repositories dynamically, then operate on each.

```yaml
name: Cross-Repo Policy Enforcement

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 1'  # Weekly on Monday

jobs:
  discover:
    runs-on: ubuntu-latest
    outputs:
      repositories: ${{ steps.list.outputs.repositories }}
    steps:
      - name: Generate org-scoped token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Discover repositories
        id: list
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
        run: |
          # Find all repositories with specific topic
          REPOS=$(gh repo list adaptive-enforcement-lab \
            --limit 100 \
            --json nameWithOwner,repositoryTopics \
            --jq '[.[] | select(.repositoryTopics[].name == "security-enforced") | .nameWithOwner]')

          echo "repositories=$REPOS" >> $GITHUB_OUTPUT
          echo "Found $(echo $REPOS | jq length) repositories"

  distribute:
    needs: discover
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repository: ${{ fromJson(needs.discover.outputs.repositories) }}
      fail-fast: false
    steps:
      - name: Generate token for distribution
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Check repository compliance
        env:
          GH_TOKEN: ${{ steps.app_token.outputs.token }}
          REPO: ${{ matrix.repository }}
        run: |
          echo "## Checking $REPO" >> $GITHUB_STEP_SUMMARY

          # Check branch protection
          PROTECTION=$(gh api repos/$REPO/branches/main/protection \
            --jq '{
              required_approvals: .required_pull_request_reviews.required_approving_review_count,
              dismiss_stale_reviews: .required_pull_request_reviews.dismiss_stale_reviews,
              require_code_owner_reviews: .required_pull_request_reviews.require_code_owner_reviews
            }' 2>/dev/null || echo "No protection")

          echo "- **Branch Protection**: $PROTECTION" >> $GITHUB_STEP_SUMMARY

  summary:
    needs: [discover, distribute]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Generate summary
        run: |
          echo "## Compliance Check Complete" >> $GITHUB_STEP_SUMMARY
          echo "- **Repositories Scanned**: ${{ fromJson(needs.discover.outputs.repositories) | length }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: ${{ needs.distribute.result }}" >> $GITHUB_STEP_SUMMARY
```

!!! tip "Three-Stage Pattern"

    This Discovery → Distribution → Summary pattern is the standard for cross-repository operations. It provides scalability and clear reporting.

## Pattern 2: Synchronized Updates

Apply the same change across multiple repositories.

```yaml
name: Synchronized Workflow Update

on:
  workflow_dispatch:
    inputs:
      workflow_file:
        description: 'Workflow file to update'
        required: true
        default: '.github/workflows/security-scan.yml'
      target_repos:
        description: 'Target repositories (JSON array)'
        required: true
        default: '["repo1", "repo2", "repo3"]'

jobs:
  update:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repository: ${{ fromJson(github.event.inputs.target_repos) }}
    steps:
      - name: Checkout template
        uses: actions/checkout@v4
        with:
          path: template

      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Checkout target repository
        uses: actions/checkout@v4
        with:
          repository: adaptive-enforcement-lab/${{ matrix.repository }}
          token: ${{ steps.app_token.outputs.token }}
          path: target

      - name: Update workflow file
        run: |
          # Copy template to target
          mkdir -p target/.github/workflows
          cp template/${{ github.event.inputs.workflow_file }} \
             target/${{ github.event.inputs.workflow_file }}

          cd target

          # Check for changes
          if git diff --quiet; then
            echo "No changes needed for ${{ matrix.repository }}"
            exit 0
          fi

          # Commit and push
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git add ${{ github.event.inputs.workflow_file }}
          git commit -m "chore: update security scan workflow

          Synchronized from central template repository.

          🤖 Generated with [Claude Code](https://claude.com/claude-code)

          Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

          git push
```

## Pattern 3: Parallel Repository Operations

Execute operations concurrently across repositories.

```yaml
name: Parallel Security Audit

on:
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        repository:
          - frontend-app
          - backend-api
          - infrastructure
          - documentation
      max-parallel: 4
    steps:
      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          repositories: ${{ matrix.repository }}

      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          repository: adaptive-enforcement-lab/${{ matrix.repository }}
          token: ${{ steps.app_token.outputs.token }}

      - name: Run security audit
        run: |
          echo "## Security Audit: ${{ matrix.repository }}" >> $GITHUB_STEP_SUMMARY

          # Check for secrets in code
          if grep -r "api[_-]key\|password\|secret" --include="*.js" --include="*.py" .; then
            echo "⚠️ Potential secrets found" >> $GITHUB_STEP_SUMMARY
          else
            echo "✅ No hardcoded secrets detected" >> $GITHUB_STEP_SUMMARY
          fi

          # Check dependencies
          if [ -f "package.json" ]; then
            npm audit --json > audit.json || true
            VULNERABILITIES=$(jq '.metadata.vulnerabilities.total' audit.json)
            echo "- **npm vulnerabilities**: $VULNERABILITIES" >> $GITHUB_STEP_SUMMARY
          fi

      - name: Upload audit results
        uses: actions/upload-artifact@v4
        with:
          name: audit-${{ matrix.repository }}
          path: audit.json
          if-no-files-found: ignore
```
