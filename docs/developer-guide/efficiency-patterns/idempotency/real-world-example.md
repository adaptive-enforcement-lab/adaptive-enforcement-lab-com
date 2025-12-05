---
title: Real-World Example
description: >-
  Idempotency in practice: file distribution across 40 repositories.
  Branch, commit, PR, and push operations all made rerun-safe.
---

# Real-World Example: File Distribution

A workflow distributing files to 40 repositories needs idempotency at multiple levels. For the complete implementation, see the [File Distribution Use Case](../../../operator-manual/github-actions/use-cases/file-distribution/index.md) in the Operator Manual.

---

## Branch Level

```bash
# Idempotent branch preparation
if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
  git checkout -B "$BRANCH" "origin/$BRANCH"
else
  git checkout -b "$BRANCH"
fi
```

**Pattern**: Check-Before-Act with force reset

**Why**: The `-B` flag force-resets the branch to remote state, eliminating drift from previous failed runs.

---

## Change Detection Level

```bash
# Idempotent change detection (handles tracked AND untracked files)
if [ -z "$(git status --porcelain)" ]; then
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
else
  echo "has_changes=true" >> "$GITHUB_OUTPUT"
fi
```

**Pattern**: State inspection before action

**Why**: Uses `git status --porcelain` instead of `git diff --quiet` to detect both modified tracked files AND new untracked files. See [Git Diff Lies](../../../blog/posts/2025-11-26-git-diff-lies.md) for the full story on this bug.

---

## Commit Level

```bash
# Only commit if changes exist
if [ "$HAS_CHANGES" == "true" ]; then
  git add .
  git commit -m "Update from central repo"
fi
```

**Pattern**: Conditional execution based on detected state

**Why**: Prevents empty commits and "nothing to commit" errors on rerun.

---

## PR Level

```bash
# Only create PR if none exists
EXISTING=$(gh pr list --head "$BRANCH" --base "$DEFAULT_BRANCH" --json number --jq 'length')
if [ "$EXISTING" -eq 0 ]; then
  gh pr create --title "Automated update" --body "From central repo"
else
  echo "PR already exists"
fi
```

**Pattern**: Check-Before-Act

**Why**: Prevents duplicate PRs. Checks for existing PR with same head branch before creating.

---

## Push Level

```bash
# Force push to handle diverged branches
git push --force-with-lease -u origin "$BRANCH"
```

**Pattern**: Force Overwrite with safety

**Why**: `--force-with-lease` overwrites remote but fails if someone else pushed changes, preventing accidental overwrites.

---

## The Result

!!! tip "Rerun Without Fear"

    The entire workflow can be rerun at any point. Failed repos retry cleanly. Successful repos skip efficiently.

| Operation | Idempotency Pattern | Behavior on Rerun |
|-----------|--------------------|--------------------|
| Branch checkout | Check + Force reset | Resets to remote state |
| Change detection | State inspection | Reports same result |
| Commit | Conditional | Skips if no changes |
| PR creation | Check-Before-Act | Skips if PR exists |
| Push | Force with lease | Updates or no-ops |
