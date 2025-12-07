---
title: "Stage 2: Distribution"
description: >-
  Parallel distribution to target repositories using matrix strategy.
---

# Stage 2: Parallel Distribution

Distribute files to all repositories using matrix strategy.

!!! tip "Fail-Fast: False"
    Always set `fail-fast: false` so one failing repository doesn't cancel others. Process all targets, report all failures.

## Implementation

```yaml
distribute:
  name: Distribute to ${{ matrix.repo.name }}
  needs: discover
  runs-on: ubuntu-latest
  if: needs.discover.outputs.count > 0
  strategy:
    matrix:
      repo: ${{ fromJson(needs.discover.outputs.repositories) }}
    fail-fast: false
    max-parallel: 10
  steps:
    - name: Checkout source repository
      uses: actions/checkout@v4

    - name: Generate authentication token
      id: auth
      uses: actions/create-github-app-token@v2
      with:
        app-id: ${{ secrets.CORE_APP_ID }}
        private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
        owner: your-org

    - name: Clone target repository
      env:
        GH_TOKEN: ${{ steps.auth.outputs.token }}
      run: |
        gh repo clone your-org/${{ matrix.repo.name }} target

    - name: Prepare branch
      working-directory: target
      run: |
        # Branch management script (see below)
        ../scripts/prepare-branch.sh \
          automated-update \
          ${{ matrix.repo.default_branch }}

    - name: Copy files
      run: |
        cp source-file.txt target/destination-file.txt

    - name: Check for changes
      id: changes
      working-directory: target
      run: |
        # Use git status --porcelain to detect both modified AND new untracked files
        # git diff --quiet only sees tracked file changes, missing new files entirely
        if [ -z "$(git status --porcelain)" ]; then
          echo "has_changes=false" >> $GITHUB_OUTPUT
        else
          echo "has_changes=true" >> $GITHUB_OUTPUT
        fi

    - name: Commit changes
      if: steps.changes.outputs.has_changes == 'true'
      working-directory: target
      run: |
        git config user.name "automation-bot"
        git config user.email "automation@your-org.com"

        git add destination-file.txt
        git commit -m "chore: update file from central repository"

    - name: Push changes
      if: steps.changes.outputs.has_changes == 'true'
      working-directory: target
      env:
        GH_TOKEN: ${{ steps.auth.outputs.token }}
      run: |
        git push -u origin automated-update

    - name: Create or update pull request
      if: steps.changes.outputs.has_changes == 'true'
      working-directory: target
      env:
        GH_TOKEN: ${{ steps.auth.outputs.token }}
      run: |
        # Check if PR exists
        PR_EXISTS=$(gh pr list \
          --head automated-update \
          --base ${{ matrix.repo.default_branch }} \
          --json number \
          --jq 'length')

        if [ "$PR_EXISTS" -eq 0 ]; then
          gh pr create \
            --base ${{ matrix.repo.default_branch }} \
            --title "chore: automated file update" \
            --body "Automated distribution from central repository"
        else
          echo "PR already exists, commits were pushed to update it"
        fi
```

## Key Features

- Matrix spawns parallel jobs per repository
- `fail-fast: false` ensures all repos process even if one fails
- `max-parallel: 10` limits concurrent jobs to avoid rate limits
- Idempotent: checks for changes before committing
