# Work Avoidance Anti-Patterns

Common mistakes that undermine work avoidance strategies.

---

## Over-Aggressive Skipping

Skipping based on insufficient criteria leads to missed updates.

### The Problem

```python
# BAD: Skipping based on filename only
if target_file.exists():
    skip()  # Content might have changed!
```

### The Fix

```python
# GOOD: Check content, not just existence
if target_file.exists() and content_matches(source, target_file):
    skip()
```

**Rule**: Always verify the **condition you care about**, not a proxy for it.

---

## Ignoring Error States

Assuming a marker means success can hide failures.

### The Problem

```python
# BAD: Marker exists but work might have failed
if cache_marker.exists():
    skip()  # Previous run might have failed after creating marker
```

### The Fix

```python
# GOOD: Validate the cached result
if cache_marker.exists() and validate_cache(cache_marker):
    skip()
```

**Rule**: Always validate cached or previous results before trusting them.

---

## Stripping Too Much

Overly broad patterns destroy semantic content.

### The Problem

```python
# BAD: Stripping all numbers (destroys semantic content)
content = re.sub(r'\d+', '', content)

# Turns "max_connections: 100" into "max_connections: "
```

### The Fix

```python
# GOOD: Strip only known volatile patterns
content = re.sub(r'^version:\s*[\d.]+\s*#.*$', '', content, flags=re.MULTILINE)
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

```python
# BAD: Race condition window
if not resource_exists():      # Check
    time.sleep(1)              # Window for race
    create_resource()          # Use - might fail if created by another process
```

### The Fix

```python
# GOOD: Atomic operation or graceful conflict handling
try:
    create_resource()
except AlreadyExistsError:
    log("Created by another process, continuing")
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

```python
# BAD: Hardcoded list - requires code changes to update
SKIP_REPOS = ["legacy-app", "deprecated-service"]

if repo in SKIP_REPOS:
    skip()
```

### The Fix

```python
# GOOD: Dynamic detection
if repo.archived or "deprecated" in repo.topics:
    skip()
```

**Rule**: Derive skip conditions from data, not hardcoded lists.

---

## Summary

| Anti-Pattern | Symptom | Fix |
|--------------|---------|-----|
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
