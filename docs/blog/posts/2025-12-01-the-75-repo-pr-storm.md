---
title: The 75-Repo PR Storm We Almost Created
date: 2025-12-01
authors:
  - mark
categories:
  - CI/CD
  - GitHub Actions
  - Engineering Patterns
description: >-
  A version bump nearly triggered 75 useless PRs across our organization.
  Content-based change detection saved us from PR fatigue.
slug: the-75-repo-pr-storm
provenance: human
---
# The 75-Repo PR Storm We Almost Created

The workflow looked perfect. CONTRIBUTING.md in our central repository, automatically distributed to all 75 repositories. Any change triggers PRs across the organization.

Then release-please bumped the version from 1.4.1 to 1.4.2.

<!-- more -->

---

## The Setup

We track CONTRIBUTING.md version alongside our platform version using [release-please extra-files](../../build/release-pipelines/release-please/extra-files.md).

The file's frontmatter carries `version: 1.4.2 # x-release-please-version`, and release-please rewrites that number on every release.

When someone merges a `feat:` commit, release-please bumps the version everywhere. This includes CONTRIBUTING.md. The file distribution workflow sees "file changed" and springs into action.

---

## The Problem

!!! danger "The Risk"
    Simple change detection catches everything. This includes version-only changes that don't matter.

Our change detection was simple.

It checked `git status --porcelain`: empty output meant no changes, anything else meant a PR.

This catches everything. Including version-only changes.

The workflow would have created 75 PRs, each containing exactly one line difference:

```diff
- version: 1.4.1 # x-release-please-version
+ version: 1.4.2 # x-release-please-version
```

Seventy-five PRs. Seventy-five notifications. Seventy-five reviews needed. Zero meaningful content.

---

## The Discovery

We caught it before it ran. The release-please PR merged, the distribution workflow triggered, and we watched the logs.

> `Processing repo 1/75: service-alpha`, then `Changes detected: true`, then `Creating PR...`

Wait. What changes? We hadn't touched the content.

The version bump. That's all that changed.

---

## The Fix

Compare content **after stripping volatile fields**.

A `strip_version` function deletes the `x-release-please-version` line with `sed`, from both the source file and `git show HEAD:CONTRIBUTING.md`.
If the two results match, the script restores the file and sets `has_changes=false`.
The [content comparison guide](../../patterns/github-actions/use-cases/work-avoidance/content-comparison.md) has the full script.

The sed pattern strips the version line before comparison. If the remaining content is identical, skip the distribution.

---

## The Result

Next workflow run:

```text
Processed: 75 repositories
PRs created: 0
Reason: Version-only changes detected, distribution skipped
```

Exactly right. The version bumped, the workflow ran, and nothing happened. Because nothing needed to happen.

---

## Edge Cases

The script handles several scenarios:

| Scenario | Behavior |
| ---------- | ---------- |
| No changes at all | Skip immediately |
| Version-only change | Strip, compare, skip |
| Content + version change | Distribute (real changes) |
| File missing in target | Distribute (new file) |

The `git show HEAD:CONTRIBUTING.md` command fails if the file doesn't exist in the target repo. That's fine. Fall through and distribute.

---

## The Pattern

!!! tip "Work Avoidance"
    Filter out noise before it becomes PRs. Compare semantic content, not file bytes.

This is [work avoidance](../../patterns/efficiency/work-avoidance/index.md). It's an engineering pattern for filtering out noise. The specific technique here is [volatile field exclusion](../../patterns/efficiency/work-avoidance/techniques/volatile-field-exclusion.md).

The principle extends beyond versions:

- Strip timestamps from generated files
- Ignore whitespace-only changes
- Filter out auto-generated comments

If the semantic content hasn't changed, the operation probably isn't needed.

---

## Lessons Learned

1. **File change ≠ meaningful change** - `git status` detects everything, including noise
2. **Test with dry runs** - Watch logs before enabling PR creation
3. **Version coupling has consequences** - Tracking versions in distributed files creates update cascades
4. **Work avoidance saves more than compute** - It saves developer attention

---

## Deep Dive

- [Work Avoidance Pattern](../../patterns/efficiency/work-avoidance/index.md) - Engineering pattern and techniques
- [Content Comparison (GitHub Actions)](../../patterns/github-actions/use-cases/work-avoidance/content-comparison.md) - Implementation for workflows
- [Release-Please Extra-Files](../../build/release-pipelines/release-please/extra-files.md) - Version tracking in arbitrary files
- [File Distribution Workflow](../../patterns/github-actions/use-cases/file-distribution/index.md) - Three-stage distribution architecture

---

*The next time release-please bumps our version, 75 repositories will quietly ignore it. As they should.*
