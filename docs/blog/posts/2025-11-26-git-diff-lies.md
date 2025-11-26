---
date: 2025-11-26
authors:
  - mark
categories:
  - DevSecOps
  - GitHub Actions
  - Automation
slug: git-diff-lies-the-untracked-file-trap
---

# Git Diff Lies: The Untracked File Trap in CI/CD Pipelines

A two-character fix to a change detection script. That's all it took to unblock a file distribution workflow that had been silently failing for weeks.

The bug? `git diff --quiet` doesn't see untracked files. And when you're distributing files to repositories that don't have them yet, every target file is untracked.

This post dissects the bug, explains why it's so easy to miss, and shows the fix that makes change detection actually work.

<!-- more -->

---

## The Scenario

A file distribution workflow copies a standardized file (like CONTRIBUTING.md) from a central repository to dozens of target repositories. The workflow:

1. Clones each target repository
2. Copies the file from source
3. Checks if anything changed
4. Creates a PR if changes exist

Simple enough. Except for step 3.

---

## The Bug

Here's the change detection logic that shipped:

```bash
if git diff --quiet; then
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  echo "No changes needed"
else
  echo "has_changes=true" >> "$GITHUB_OUTPUT"
fi
```

Looks reasonable. `git diff --quiet` exits 0 if there are no differences, 1 if there are. Standard pattern.

**The problem**: `git diff` only compares the working directory against the index for **tracked files**.

When you copy a file into a repository that doesn't have it yet, that file is **untracked**. Git diff doesn't know it exists. It reports "no changes" because, from its perspective, nothing changed.

!!! failure "The Silent Failure"

    Workflow runs successfully.
    Logs show "No changes needed."
    No PRs created.
    No errors.

    Perfect green checkmarks hiding complete failure.

---

## Why This Bug Is Insidious

Three factors make this bug particularly nasty:

### 1. It Works... Sometimes

If the target repository already has the file and you're updating it, `git diff` works perfectly. The file is tracked. Changes are detected. PRs get created.

The bug only manifests for repositories **missing the file entirely**. These are often new repositories or edge cases—exactly the ones you're least likely to test manually.

### 2. Green CI Masks the Failure

The workflow doesn't fail. It completes successfully with:

```text
No changes needed
```

No error. No warning. Just a lie.

CI dashboards show green. Notifications don't fire. The only symptom is the absence of expected PRs—which requires someone to notice something didn't happen.

### 3. The Pattern Looks Correct

`git diff --quiet` is a legitimate idiom. Search Stack Overflow, read shell scripting guides, check other workflows—you'll find this pattern everywhere.

It's not wrong. It's just incomplete.

---

## The Fix

Replace `git diff --quiet` with `git status --porcelain`:

```bash
if [ -z "$(git status --porcelain)" ]; then
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  echo "No changes needed"
else
  echo "has_changes=true" >> "$GITHUB_OUTPUT"
fi
```

### Why This Works

`git status --porcelain` outputs:

- Modified tracked files (`M`)
- New untracked files (`??`)
- Deleted files (`D`)
- Renamed files (`R`)

The `--porcelain` flag guarantees machine-parseable output that won't change between Git versions. If the output is empty, the working directory is clean. If it's not empty, something changed.

### The Behavior Difference

| Scenario | `git diff --quiet` | `git status --porcelain` |
|----------|-------------------|-------------------------|
| Modified tracked file | Detects | Detects |
| New untracked file | **Misses** | Detects |
| Deleted tracked file | Detects | Detects |
| Renamed file | Depends | Detects |

---

## Side-by-Side Comparison

### Before (Broken)

```bash
#!/bin/bash
set -e

# Checks if there are uncommitted changes in git working directory

if git diff --quiet; then
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  echo "No changes needed"
else
  echo "has_changes=true" >> "$GITHUB_OUTPUT"
fi
```

### After (Fixed)

```bash
#!/bin/bash
set -e

# Checks if there are uncommitted changes in git working directory
# Uses git status --porcelain to detect both modified tracked files AND new untracked files

if [ -z "$(git status --porcelain)" ]; then
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  echo "No changes needed"
else
  echo "has_changes=true" >> "$GITHUB_OUTPUT"
fi
```

One conditional swap. One comment added. Bug eliminated.

---

## Testing the Fix

You can verify this behavior in any Git repository:

```bash
# Create a test repo
mkdir test-repo && cd test-repo
git init

# Create and commit an initial file
echo "tracked" > tracked.txt
git add tracked.txt
git commit -m "Initial commit"

# Test 1: Modify tracked file
echo "modified" > tracked.txt
echo "git diff exit code: $(git diff --quiet; echo $?)"  # Returns 1 (changes)
echo "git status output: '$(git status --porcelain)'"    # Shows: M tracked.txt
git checkout -- tracked.txt

# Test 2: Add untracked file
echo "new" > untracked.txt
echo "git diff exit code: $(git diff --quiet; echo $?)"  # Returns 0 (no changes!)
echo "git status output: '$(git status --porcelain)'"    # Shows: ?? untracked.txt
```

The difference is obvious when you test it. The challenge is remembering to test the untracked file case.

---

## Lessons Learned

### Test the Edge Cases

The happy path (updating existing files) worked. The edge case (adding new files) didn't. Edge cases are where bugs hide.

### Green CI Doesn't Mean Correct

A successful workflow run only means the workflow executed without errors. It doesn't mean it did what you intended. Silent failures are worse than loud ones.

### Question Common Patterns

`git diff --quiet` is common. Common doesn't mean correct for your use case. Understand what commands actually do, not just what they're commonly used for.

### Add Debug Output

The fixed version includes additional logging:

```bash
echo "Changes detected:"
git status --short
```

When something goes wrong, visibility into state is invaluable. Silent success is just silent failure you haven't noticed yet.

---

## The Broader Pattern

This bug represents a category of CI/CD failures: **operations that succeed with incomplete detection**.

Other examples:

- Testing only the paths that exist, missing coverage for new paths
- Validating configuration for known keys, ignoring unknown keys
- Checking file permissions on existing files, missing new files
- Rate limiting based on successful requests, missing failed ones

The pattern: your detection logic was designed for one set of conditions, but production includes conditions you didn't anticipate.

The defense: explicit enumeration of what you're detecting, regular review of edge cases, and visibility into what your automation actually does.

---

## Conclusion

One conditional swap. `[ -z "$(git status --porcelain)" ]` instead of `git diff --quiet`.

The distribution workflow now correctly detects new files and creates PRs for repositories that need them. Thirty-plus repositories that were silently skipped now receive their updates.

Next time you write change detection in a CI/CD pipeline, remember: `git diff` is for comparing tracked files. `git status` is for understanding working directory state. Use the right tool for the job.

---

*Found a bug in your automation? That's not failure—that's learning. Document it, fix it, share it.*
