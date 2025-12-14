---
title: Idempotency
description: >-
  Safe re-execution guarantees for file distribution workflows.
---

# Idempotency in File Distribution

This workflow applies [idempotency patterns](../../../../developer-guide/efficiency-patterns/idempotency/index.md) to ensure safe reruns.

!!! tip "Learn the Pattern"

    For comprehensive coverage of idempotency patterns, see the [Developer Guide: Idempotency](../../../../developer-guide/efficiency-patterns/idempotency/index.md).

---

## Applied Patterns

### Branch Management: Force Overwrite

Uses [force overwrite](../../../../developer-guide/efficiency-patterns/idempotency/patterns/force-overwrite.md) to reset branch state:

```bash
# Force reset to remote state - idempotent
git checkout -B "$BRANCH_NAME" "origin/$BRANCH_NAME"
```

### Change Detection: Check-Before-Act {#change_detection}

Uses [check-before-act](../../../../developer-guide/efficiency-patterns/idempotency/patterns/check-before-act.md) to avoid empty commits.

!!! tip "Content-Level Filtering"

    For smarter detection that ignores version-only changes, see
    [Content Comparison](../work-avoidance/content-comparison.md).

```yaml
- name: Check for changes
  id: changes
  working-directory: target
  run: |
    # git status --porcelain detects all changes
    if [ -z "$(git status --porcelain)" ]; then
      echo "has_changes=false" >> $GITHUB_OUTPUT
    else
      echo "has_changes=true" >> $GITHUB_OUTPUT
    fi

- name: Commit changes
  if: steps.changes.outputs.has_changes == 'true'
  # Only runs if changes exist
```

!!! warning "Use `git status`, not `git diff`"

    `git diff --quiet` only detects modifications to **tracked files**.
    New files are **untracked** and invisible to `git diff`.

    Use `git status --porcelain` instead—it detects everything.

### PR Creation: Upsert

Uses [upsert pattern](../../../../developer-guide/efficiency-patterns/idempotency/patterns/upsert.md) for PR management:

```yaml
- name: Create or update pull request
  run: |
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

---

## Safe Re-execution

| Operation | First Run | Subsequent Runs |
| ----------- | ----------- | ----------------- |
| Branch creation | Creates new branch | Resets to remote state |
| File copy | Copies files | Overwrites with same content |
| Change detection | Detects changes | Reports no changes |
| Commit | Creates commit | Skipped (no changes) |
| PR creation | Creates PR | Updates existing PR |

---

## Why This Matters

Matrix jobs processing 40 repositories might fail on job 37 due to rate limiting. With idempotent operations:

1. Rerun the entire workflow
2. Jobs 1-36 detect "no changes" and skip
3. Jobs 37-40 retry and succeed

Without idempotency, you'd need to manually identify which repos succeeded and run only the failures.

---

## Related

- [Work Avoidance Pattern](../../../../developer-guide/efficiency-patterns/work-avoidance/index.md) - Engineering pattern for skipping unnecessary work
- [Content Comparison](../work-avoidance/content-comparison.md) - Skip version-only changes (GitHub Actions)
- [Idempotency Patterns](../../../../developer-guide/efficiency-patterns/idempotency/index.md) - Theory and decision matrix
