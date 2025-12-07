# Volatile Field Exclusion

Strip fields that change without affecting semantics before comparison.

!!! tip "Key Insight"
    Version numbers, timestamps, and build IDs change automatically. Exclude them before comparing to avoid false positives.

---

## The Technique

Some fields change automatically without representing meaningful changes. These include version numbers, timestamps, build IDs, and generated comments. When these fields update, they create noise in content comparisons.

Common volatile fields include:

- Version numbers (bumped by release automation)
- Timestamps (updated on every generation)
- Build IDs (change every build)
- Generated comments (auto-updated headers)

Exclude these fields before comparing content. This prevents false positives from triggering unnecessary work.

```go
package main

import (
    "regexp"
    "strings"
)

var volatilePatterns = []*regexp.Regexp{
    regexp.MustCompile(`(?m)^version:.*# x-release-please-version$`),
    regexp.MustCompile(`(?m)^updated:\s*\d{4}-\d{2}-\d{2}`),
    regexp.MustCompile(`(?m)^generated:\s*.*$`),
}

func stripVolatile(content string) string {
    result := content
    for _, pattern := range volatilePatterns {
        result = pattern.ReplaceAllString(result, "")
    }
    return strings.TrimSpace(result)
}

func meaningfulChange(source, target string) bool {
    return stripVolatile(source) != stripVolatile(target)
}
```

---

## When to Use

This technique applies when automated processes update fields that don't affect functionality. Consider using volatile field exclusion when:

- **Release automation** bumps versions in distributed files.
- **Generated files** include timestamps or build metadata.
- **Config files** have auto-updated fields.
- **Documentation** contains version headers.

---

## Common Volatile Fields

| Field Type | Examples | Pattern |
|------------|----------|---------|
| Version stamps | `version: 1.2.3` | `^version:\s*[\d.]+` |
| Release annotations | `version: 1.2.3 # x-release-please-version` | `^version:.*# x-release-please-version$` |
| Timestamps | `updated: 2025-01-01` | `^updated:\s*\d{4}-\d{2}-\d{2}` |
| Build IDs | `buildId: abc123` | `^buildId:\s*\w+` |
| Generated markers | `# Auto-generated on ...` | `^#\s*Auto-generated.*$` |
| Self-checksums | `sha256: abc...` | `^sha256:\s*[a-f0-9]+` |

---

## Implementation Patterns

### Markdown with YAML Frontmatter

```bash
#!/bin/bash
# Strip version line from markdown frontmatter

strip_version() {
  sed '/^version:.*# x-release-please-version$/d' "$1"
}

SOURCE=$(strip_version "source/CONFIG.md")
TARGET=$(git show HEAD:CONFIG.md 2>/dev/null | \
  sed '/^version:.*# x-release-please-version$/d' || echo "")

if [ "$SOURCE" = "$TARGET" ]; then
  echo "Only version changed, skipping"
else
  echo "Content changed, distributing"
fi
```

### JSON Files

```bash
# Strip volatile fields from JSON using jq
strip_volatile_json() {
  jq 'del(.version, .timestamp, .buildId, .metadata.generated)' "$1"
}

SOURCE=$(strip_volatile_json "config.json")
TARGET=$(git show HEAD:config.json | jq 'del(.version, .timestamp, .buildId, .metadata.generated)')

if [ "$SOURCE" = "$TARGET" ]; then
  echo "No meaningful changes"
fi
```

### YAML Files

```bash
# Strip volatile fields from YAML using yq
strip_volatile_yaml() {
  yq 'del(.metadata.version, .metadata.timestamp, .spec.generation)' "$1"
}

SOURCE=$(strip_volatile_yaml "resource.yaml")
TARGET=$(strip_volatile_yaml "deployed.yaml")

if [ "$SOURCE" = "$TARGET" ]; then
  echo "No meaningful changes"
fi
```

### Multiple Patterns

```bash
strip_volatile() {
  sed -e '/^version:.*# x-release-please-version$/d' \
      -e '/^updated:\s*[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/d' \
      -e '/^generated:\s*/d' \
      -e '/^# Auto-generated/d' \
      "$1"
}
```

---

## Pattern Design

Design patterns carefully to avoid stripping meaningful content. Follow these guidelines.

### Be Specific

```bash
# BAD: Too broad - might strip meaningful content
sed '/version/d' "$1"

# GOOD: Specific pattern with markers
sed '/^version:.*# x-release-please-version$/d' "$1"
```

### Use Markers

Add explicit markers to volatile fields. This makes them easy to identify and strip reliably.

```yaml
# In your source file
version: 1.2.3  # x-release-please-version
updated: 2025-01-01  # auto-updated
```

The markers make stripping patterns unambiguous. Use consistent markers across your codebase.

```bash
sed '/#\s*x-release-please-version$/d'
sed '/#\s*auto-updated$/d'
```

### Document Patterns

Keep volatile field patterns documented alongside the comparison logic. This helps maintainers understand what gets stripped and why.

```bash
# VOLATILE_FIELDS.md
# These fields are excluded from content comparison:
# - version: X.Y.Z # x-release-please-version (release automation)
# - updated: YYYY-MM-DD (generation timestamp)
# - buildId: (CI build identifier)
```

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Pattern matches content | Use more specific markers |
| Multiple volatile fields | Chain sed expressions |
| Nested fields (JSON/YAML) | Use jq/yq instead of sed |
| Binary files | Not applicable (use hashing) |

---

## Real-World Example

This example shows a file distribution workflow that skips version-only changes. The workflow compares stripped content to detect meaningful updates.

```yaml
- name: Check for meaningful changes
  id: check
  run: |
    strip_version() {
      sed '/^version:.*# x-release-please-version$/d' "$1"
    }

    SOURCE=$(strip_version "CONTRIBUTING.md")
    ORIGINAL=$(git show HEAD:CONTRIBUTING.md | \
      sed '/^version:.*# x-release-please-version$/d' || echo "NEW_FILE")

    if [ "$SOURCE" = "$ORIGINAL" ]; then
      echo "skip=true" >> $GITHUB_OUTPUT
      echo "Version-only change, skipping distribution"
    else
      echo "skip=false" >> $GITHUB_OUTPUT
    fi

- name: Create PR
  if: steps.check.outputs.skip != 'true'
  run: gh pr create ...
```

---

## Related

- [Content Hashing](content-hashing.md) - When exact comparison is needed
- [Techniques Overview](index.md) - All work avoidance techniques
- [Content Comparison (GitHub Actions)](../../../../operator-manual/github-actions/use-cases/work-avoidance/content-comparison.md) - CI/CD implementation
