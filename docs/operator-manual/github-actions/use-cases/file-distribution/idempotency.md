---
title: Idempotency
description: >-
  Safe re-execution guarantees for file distribution workflows.
---

# Idempotency Guarantees

The workflow is designed to be fully idempotent.

## Branch Management

- `git checkout -B` forces reset to remote state
- No merge conflicts on subsequent runs
- Safe to run multiple times

```bash
# Force reset to remote state
git checkout -B "$BRANCH_NAME" "origin/$BRANCH_NAME"
```

## Change Detection

- Checks if file content actually changed
- Detects both modified tracked files AND new untracked files
- Skips commit/push if no changes
- Avoids empty commits

!!! warning "Use `git status`, not `git diff`"

    `git diff --quiet` only detects modifications to **tracked files**.
    When distributing files to repos that don't have them yet,
    new files are **untracked** and `git diff` won't see them.

    Use `git status --porcelain` instead—it detects everything.

```yaml
- name: Check for changes
  id: changes
  working-directory: target
  run: |
    # git status --porcelain detects:
    # - Modified tracked files
    # - New untracked files
    # - Deleted files
    # - Renamed files
    if [ -z "$(git status --porcelain)" ]; then
      echo "has_changes=false" >> $GITHUB_OUTPUT
      echo "No changes needed"
    else
      echo "has_changes=true" >> $GITHUB_OUTPUT
      echo "Changes detected:"
      git status --short
    fi

- name: Commit changes
  if: steps.changes.outputs.has_changes == 'true'
  # Only runs if changes exist
```

## PR Management

- Checks for existing PRs before creating
- Updates existing PRs with new commits
- No duplicate PRs created

```yaml
- name: Create or update pull request
  run: |
    # Check if PR exists
    PR_EXISTS=$(gh pr list \
      --head automated-update \
      --base ${{ matrix.repo.default_branch }} \
      --json number \
      --jq 'length')

    if [ "$PR_EXISTS" -eq 0 ]; then
      gh pr create ...
    else
      echo "PR already exists, commits were pushed to update it"
    fi
```

## Safe Re-execution

| Operation | First Run | Subsequent Runs |
|-----------|-----------|-----------------|
| Branch creation | Creates new branch | Resets to remote state |
| File copy | Copies files | Overwrites with same content |
| Change detection | Detects changes | Reports no changes |
| Commit | Creates commit | Skipped (no changes) |
| PR creation | Creates PR | Updates existing PR |
