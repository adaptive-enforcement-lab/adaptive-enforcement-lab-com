---
description: >-
  Common work avoidance mistakes: over-aggressive skipping, ignoring errors, stripping too much, stale caches, silent failures, and race conditions with fixes.
---

# Work Avoidance Anti-Patterns

!!! warning "Common Pitfalls"
    These mistakes undermine work avoidance strategies and lead to false positives or missed updates.

---

## Over-Aggressive Skipping

Skipping based on insufficient criteria leads to missed updates.

### The Problem

```go
// BAD: Skipping based on filename only
if _, err := os.Stat(targetFile); err == nil {
    return // Content might have changed!
}
```

### The Fix

```go
// GOOD: Check content, not just existence
if _, err := os.Stat(targetFile); err == nil {
    if contentMatches(source, targetFile) {
        return
    }
}
```

**Rule**: Always verify the **condition you care about**, not a proxy for it.

---

## Ignoring Error States

Assuming a marker means success can hide failures.

### The Problem

```go
// BAD: Marker exists but work might have failed
if _, err := os.Stat(cacheMarker); err == nil {
    return // Previous run might have failed after creating marker
}
```

### The Fix

```go
// GOOD: Validate the cached result
if _, err := os.Stat(cacheMarker); err == nil {
    if validateCache(cacheMarker) {
        return
    }
}
```

**Rule**: Always validate cached or previous results before trusting them.

---

## Stripping Too Much

Overly broad patterns destroy semantic content.

### The Problem

```go
// BAD: Stripping all numbers (destroys semantic content)
content = regexp.MustCompile(`\d+`).ReplaceAllString(content, "")

// Turns "max_connections: 100" into "max_connections: "
```

### The Fix

```go
// GOOD: Strip only known volatile patterns
pattern := regexp.MustCompile(`(?m)^version:\s*[\d.]+\s*#.*$`)
content = pattern.ReplaceAllString(content, "")
```

**Rule**: Use specific patterns with markers. When in doubt, don't strip.

---

## Stale Cache Keys

Cache keys that don't include all inputs lead to stale results.

### The Problem

```yaml
# BAD: Missing dependency input
key: build-${{ hashFiles('src/**') }}
# Ignores changes to package.json!
```

### The Fix

```yaml
# GOOD: All inputs that affect output
key: build-${{ hashFiles('src/**', 'package-lock.json', 'webpack.config.js') }}
```

**Rule**: Cache keys must include **every input** that affects the output.

---

## Silent Skip Failures

Skipping without logging makes debugging impossible.

### The Problem

```bash
if [ -f ".done" ]; then
  exit 0  # Silent skip - why did it skip?
fi
```

### The Fix

```bash
if [ -f ".done" ]; then
  echo "Skipping: previous run marker found (.done exists)"
  echo "  Created: $(stat -c %y .done 2>/dev/null || stat -f %Sm .done)"
  exit 0
fi
```

**Rule**: Log **why** something was skipped, not just that it was.

---

## TOCTOU Race Conditions

Time-of-check-to-time-of-use gaps can cause duplicate work or failures.

### The Problem

```go
// BAD: Race condition window
if !resourceExists() {           // Check
    time.Sleep(time.Second)      // Window for race
    createResource()             // Use - might fail if created by another process
}
```

### The Fix

```go
// GOOD: Atomic operation or graceful conflict handling
err := createResource()
if errors.Is(err, ErrAlreadyExists) {
    log.Println("Created by another process, continuing")
    return nil
}
return err
```

**Rule**: Prefer atomic operations. When impossible, handle conflicts gracefully.

---

## Comparing Derived State

Comparing transformed data instead of source data leads to false negatives.

### The Problem

```bash
# BAD: Comparing rendered output (includes timestamps, random IDs)
if diff rendered-a.html rendered-b.html; then
  skip
fi
```

### The Fix

```bash
# GOOD: Compare source data
if diff source-a.md source-b.md; then
  skip
fi
```

**Rule**: Compare the **inputs** that determine the output, not the output itself.

---

## Hardcoded Skip Conditions

Static conditions don't adapt to changes.

### The Problem

```go
// BAD: Hardcoded list - requires code changes to update
var skipRepos = []string{"legacy-app", "deprecated-service"}

if slices.Contains(skipRepos, repo.Name) {
    return
}
```

### The Fix

```go
// GOOD: Dynamic detection
if repo.Archived || slices.Contains(repo.Topics, "deprecated") {
    return
}
```

**Rule**: Derive skip conditions from data, not hardcoded lists.

---

## Summary

| Anti-Pattern | Symptom | Fix |
| -------------- | --------- | ----- |
| Over-Aggressive Skipping | Missed updates | Verify actual condition |
| Ignoring Error States | Silent failures | Validate cached results |
| Stripping Too Much | Wrong comparisons | Use specific patterns |
| Stale Cache Keys | Stale builds | Include all inputs |
| Silent Skip Failures | Hard to debug | Log skip reasons |
| TOCTOU Race Conditions | Duplicate work | Atomic ops or conflict handling |
| Comparing Derived State | False negatives | Compare source data |
| Hardcoded Skip Conditions | Maintenance burden | Derive from data |

---

## Related

- [Techniques Overview](techniques/index.md) - Proper implementation patterns
- [Work Avoidance Overview](index.md) - Pattern introduction
