---
date: 2025-12-04
authors:
  - mark
categories:
  - CI/CD
  - GitHub Actions
  - Engineering Patterns
description: >-
  A version bump nearly triggered 41 useless PRs across our organization.
  Content-based change detection saved us from PR fatigue.
slug: the-41-repo-pr-storm
---

# The 41-Repo PR Storm We Almost Created

The workflow looked perfect. CONTRIBUTING.md in our central repository, automatically distributed to all 41 platform repositories. Any change triggers PRs across the organization.

Then release-please bumped the version from 2.5.4 to 2.5.5.

<!-- more -->

---

## The Setup

We track CONTRIBUTING.md version alongside our platform version using [release-please extra-files](../../operator-manual/github-actions/use-cases/release-pipelines/release-please/extra-files.md):

```markdown
---
title: Contributing to Platform Projects
version: 2.5.5 # x-release-please-version
---
```

When someone merges a `feat:` commit, release-please bumps the version everywhere—including CONTRIBUTING.md. The file distribution workflow sees "file changed" and springs into action.

---

## The Problem

Our change detection was simple:

```bash
if [ -z "$(git status --porcelain)" ]; then
  echo "No changes"
else
  echo "Changes detected - creating PR"
fi
```

This catches everything. Including version-only changes.

The workflow would have created 41 PRs, each containing exactly one line difference:

```diff
- version: 2.5.4 # x-release-please-version
+ version: 2.5.5 # x-release-please-version
```

Forty-one PRs. Forty-one notifications. Forty-one reviews needed. Zero meaningful content.

---

## The Discovery

We caught it before it ran. The release-please PR merged, the distribution workflow triggered, and we watched the logs:

```text
Processing repo 1/41: service-alpha
  Changes detected: true
  Creating PR...
```

Wait. What changes? We hadn't touched the content.

The version bump. That's all that changed.

---

## The Fix

Compare content **after stripping volatile fields**:

```bash
strip_version() {
  sed '/^version:.*# x-release-please-version$/d' "$1"
}

SOURCE_CONTENT=$(strip_version "CONTRIBUTING.md")
ORIGINAL_CONTENT=$(git show HEAD:CONTRIBUTING.md | \
  sed '/^version:.*# x-release-please-version$/d')

if [ "$SOURCE_CONTENT" = "$ORIGINAL_CONTENT" ]; then
  # Only version changed - skip
  git checkout -- CONTRIBUTING.md
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "has_changes=true" >> "$GITHUB_OUTPUT"
```

The sed pattern strips the version line before comparison. If the remaining content is identical, skip the distribution.

---

## The Result

Next workflow run:

```text
Processed: 41 repositories
PRs created: 0
Reason: Version-only changes detected, distribution skipped
```

Exactly right. The version bumped, the workflow ran, and nothing happened. Because nothing needed to happen.

---

## Edge Cases

The script handles several scenarios:

| Scenario | Behavior |
|----------|----------|
| No changes at all | Skip immediately |
| Version-only change | Strip, compare, skip |
| Content + version change | Distribute (real changes) |
| File missing in target | Distribute (new file) |

The `git show HEAD:CONTRIBUTING.md` command fails if the file doesn't exist in the target repo. That's fine—fall through and distribute.

---

## The Pattern

This is [work avoidance](../../developer-guide/engineering-practices/patterns/work-avoidance/index.md)—an engineering pattern for filtering out noise before it becomes PRs. The specific technique here is [volatile field exclusion](../../developer-guide/engineering-practices/patterns/work-avoidance/techniques/volatile-field-exclusion.md).

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

- [Work Avoidance Pattern](../../developer-guide/engineering-practices/patterns/work-avoidance/index.md) - Engineering pattern and techniques
- [Content Comparison (GitHub Actions)](../../operator-manual/github-actions/use-cases/work-avoidance/content-comparison.md) - Implementation for workflows
- [Release-Please Extra-Files](../../operator-manual/github-actions/use-cases/release-pipelines/release-please/extra-files.md) - Version tracking in arbitrary files
- [File Distribution Workflow](../../operator-manual/github-actions/use-cases/file-distribution/index.md) - Three-stage distribution architecture

---

*The next time release-please bumps our version, 41 repositories will quietly ignore it. As they should.*
