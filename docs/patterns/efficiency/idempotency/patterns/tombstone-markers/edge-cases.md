---
title: Edge Cases
description: >-
  Gotchas and mitigations for tombstone markers: stale markers, partial completion gaps, distributed access races, and cleanup strategies for production systems.
---
# Edge Cases

Gotchas, anti-patterns, and mitigations for tombstone markers.

---

## Markers Without Cleanup

Markers accumulate forever without cleanup:

```bash
# After 1000 runs, you have 1000 marker files
ls .done-* | wc -l
# 1000
```

!!! tip "Schedule Regular Cleanup"

    Add marker cleanup to your CI pipeline or cron jobs. Stale markers waste storage and make debugging harder.

**Mitigation**: Include cleanup in your workflow:

```bash
# Clean markers older than 7 days
find . -name ".done-*" -mtime +7 -delete
```

---

## Partial Completion

!!! danger "The Gap Between Work and Marker"

    If your script crashes after the operation succeeds but before the marker is created, a rerun will duplicate the work. The marker only helps if it's written.

Operation fails after starting but before marker creation:

```bash
perform_operation  # Succeeds partially
# Script killed here
touch "$MARKER"    # Never runs
```

**Mitigation**: Make the operation itself idempotent, or use transaction-like patterns:

```bash
MARKER=".completed-$OP"
PENDING=".pending-$OP"

# Mark as in-progress
touch "$PENDING"

if perform_operation; then
  mv "$PENDING" "$MARKER"
else
  rm -f "$PENDING"
  exit 1
fi
```

---

## Stale Markers

Marker exists but operation needs to run again:

```bash
# Marker says "done" but source changed
if [ -f "$MARKER" ]; then
  exit 0  # Skips even though we should re-run
fi
```

**Mitigation**: Include content hash in marker name:

```bash
CONTENT_HASH=$(sha256sum source.txt | cut -c1-16)
MARKER=".done-${CONTENT_HASH}"
```

---

## Distributed Marker Access

Multiple workers checking the same marker:

```bash
# Worker 1                  # Worker 2
if [ ! -f marker ]; then   if [ ! -f marker ]; then
  # Both pass check
  do_work                    do_work  # Duplicate!
  touch marker               touch marker
fi                         fi
```

**Mitigation**: Use atomic marker creation:

```bash
# mkdir fails atomically if directory exists
if mkdir ".lock-$OPERATION" 2>/dev/null; then
  do_work
  touch ".done-$OPERATION"
  rmdir ".lock-$OPERATION"
else
  echo "Another worker is processing"
fi
```

---

## Anti-Patterns

### Markers Without Context

```bash
# Bad: no idea what this marker means
touch .done

# Good: descriptive and scoped
touch ".done-migration-v2-${GITHUB_RUN_ID}"
```

### Checking Marker After Operation

```bash
# Bad: defeats the purpose
perform_operation
if [ -f "$MARKER" ]; then
  echo "Done"
fi
touch "$MARKER"

# Good: check first
if [ -f "$MARKER" ]; then
  echo "Already done"
  exit 0
fi
perform_operation
touch "$MARKER"
```

### Markers in Ephemeral Locations

```bash
# Bad: /tmp is cleared on reboot
MARKER="/tmp/.operation-done"

# Better: persistent location
MARKER="/var/lib/myapp/.operation-done"

# Or use artifact/cache for CI
```

---

## Related

- [Tombstone Markers Overview](index.md) - Pattern basics
- [CI/CD Examples](ci-cd-examples.md) - Implementation patterns
