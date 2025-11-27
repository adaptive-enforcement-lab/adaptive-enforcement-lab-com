---
title: Implementation Patterns
description: >-
  Five patterns for building idempotent automation.
  Check-before-act, upsert, force overwrite, unique identifiers, and tombstones.
---

# Implementation Patterns

Five patterns for making operations idempotent. Each has tradeoffs; choose based on your constraints.

---

## Pattern 1: Check-Before-Act

The most common pattern. Check if the target state exists before attempting to create it.

```bash
# Branch management
if git ls-remote --heads origin "$BRANCH" | grep -q "$BRANCH"; then
  git checkout -B "$BRANCH" "origin/$BRANCH"  # Reset to remote
else
  git checkout -b "$BRANCH"  # Create new
fi
```

| Pros | Cons |
|------|------|
| Simple, explicit, easy to debug | Race conditions possible between check and act |

---

## Pattern 2: Create-or-Update (Upsert)

Use APIs or commands that handle both cases atomically.

```bash
# GitHub CLI handles create-or-update for some operations
gh release create v1.0.0 --notes "Release" --target main || \
gh release edit v1.0.0 --notes "Release"
```

| Pros | Cons |
|------|------|
| Atomic, no race conditions | Not all APIs support upsert semantics |

---

## Pattern 3: Force Overwrite

Don't check - just overwrite. Safe when overwriting with identical content is acceptable.

```bash
# Force push to update branch (idempotent if content same)
git push --force-with-lease origin "$BRANCH"
```

| Pros | Cons |
|------|------|
| Simple, no check overhead | Destructive if used incorrectly, loses history |

---

## Pattern 4: Unique Identifiers

Generate deterministic IDs so duplicate operations target the same resource.

```bash
# Deterministic branch name from content hash
BRANCH="update-$(sha256sum file.txt | cut -c1-8)"
```

| Pros | Cons |
|------|------|
| Natural deduplication | ID generation logic can be complex |

---

## Pattern 5: Tombstone/Marker Files

Leave markers indicating operations completed.

```bash
MARKER=".completed-$RUN_ID"
if [ -f "$MARKER" ]; then
  echo "Already completed"
  exit 0
fi

# Do work...

touch "$MARKER"
```

| Pros | Cons |
|------|------|
| Works for any operation type | Markers can get out of sync, need cleanup |

---

## Choosing a Pattern

| Scenario | Recommended Pattern |
|----------|-------------------|
| Creating resources (PRs, branches, files) | Check-Before-Act |
| Updating existing resources | Upsert or Force Overwrite |
| Operations with natural keys | Unique Identifiers |
| Complex multi-step operations | Tombstone/Marker Files |
| API supports atomic operations | Upsert |
