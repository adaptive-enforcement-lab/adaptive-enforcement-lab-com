# Content Comparison

Skip file distribution when only version metadata changed.

!!! warning "Version Noise"
    Release automation creates PRs for version-only changes across 40+ repos. Filter them out before creating PR fatigue.

This implements the [volatile field exclusion](../../../../developer-guide/efficiency-patterns/work-avoidance/techniques/volatile-field-exclusion.md) technique for GitHub Actions workflows.

---

## The Problem

Release automation updates version numbers in distributed files:

1. Release-please bumps `version: 2.5.4` → `version: 2.5.5` in CONFIG.md
2. File distribution workflow detects "file changed"
3. Creates PRs across 40+ repositories
4. Every PR contains only a version number change

Result: PR fatigue. Developers ignore automated PRs.

---

## Implementation

### Change Detection Script

```bash
#!/bin/bash
# scripts/check-changes.sh

strip_version() {
  sed '/^version:.*# x-release-please-version$/d' "$1"
}

# Quick check: any changes at all?
if [ -z "$(git status --porcelain)" ]; then
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Changes detected - check if meaningful
if [ -f "CONTRIBUTING.md" ]; then
  SOURCE_CONTENT=$(strip_version "CONTRIBUTING.md")

  if git show HEAD:CONTRIBUTING.md > /dev/null 2>&1; then
    ORIGINAL_CONTENT=$(git show HEAD:CONTRIBUTING.md | \
      sed '/^version:.*# x-release-please-version$/d')

    if [ "$SOURCE_CONTENT" = "$ORIGINAL_CONTENT" ]; then
      git checkout -- CONTRIBUTING.md
      echo "has_changes=false" >> "$GITHUB_OUTPUT"
      exit 0
    fi
  fi
fi

echo "has_changes=true" >> "$GITHUB_OUTPUT"
```

### Workflow Integration

```yaml
- name: Copy file to target
  run: cp SOURCE.md target-repo/SOURCE.md

- name: Check for meaningful changes
  id: check-changes
  working-directory: target-repo
  run: ${{ github.workspace }}/scripts/check-changes.sh

- name: Commit and push
  if: steps.check-changes.outputs.has_changes == 'true'
  working-directory: target-repo
  run: |
    git add .
    git commit -m "chore: update SOURCE.md"
    git push
```

---

## Version Line Format

The script expects release-please version annotations:

```markdown
---
title: Contributing Guidelines
version: 2.5.5 # x-release-please-version
---
```

The sed pattern must match exactly:

```bash
sed '/^version:.*# x-release-please-version$/d'
```

---

## Edge Cases

| Scenario | Behavior |
| ---------- | ---------- |
| No changes at all | Skip immediately |
| Version-only change | Strip, compare, skip |
| Content + version change | Distribute (real changes) |
| File missing in target | Distribute (new file) |

---

## Extending for Multiple Fields

Strip additional volatile fields:

```bash
strip_volatile() {
  sed -e '/^version:.*# x-release-please-version$/d' \
      -e '/^updated:.*$/d' \
      -e '/^generated:.*$/d' \
      "$1"
}
```

For JSON/YAML files, see the [engineering pattern](../../../../developer-guide/efficiency-patterns/work-avoidance/techniques/volatile-field-exclusion.md) for jq/yq examples.

---

## Related

- [Work Avoidance Pattern](../../../../developer-guide/efficiency-patterns/work-avoidance/index.md) - Conceptual pattern
- [Release-Please Extra-Files](../release-pipelines/release-please/extra-files.md) - Version annotation format
- [File Distribution Idempotency](../file-distribution/idempotency.md) - Complementary check-before-act pattern
