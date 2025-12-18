---
title: Testing Idempotency
description: >-
  Verify idempotency by running workflows twice. Test for duplicates, same end state, performance, and partial failure recovery to ensure rerun-safe automation.
---

# Testing Idempotency

The only way to know if your automation is idempotent is to test it.

---

## The Ultimate Test

!!! info "Run It Twice"

    Run your workflow twice in a row. Does the second run:

    1. Complete without errors?
    2. Produce the same end state?
    3. Not create duplicates?
    4. Run reasonably fast (not re-doing expensive work)?

---

## Basic Test Script

```bash
# Idempotency test script
./workflow.sh
FIRST_RESULT=$?

./workflow.sh
SECOND_RESULT=$?

if [ $FIRST_RESULT -eq 0 ] && [ $SECOND_RESULT -eq 0 ]; then
  echo "Basic idempotency check passed"
else
  echo "Workflow is not idempotent"
fi
```

---

## What to Verify

### No Duplicates

After running twice, check:

- [ ] Same number of PRs (not doubled)
- [ ] Same number of commits (not duplicated)
- [ ] Same number of branches
- [ ] Same number of artifacts/releases

### Same End State

Compare final state after first and second run:

- [ ] File contents identical
- [ ] Branch HEAD points to same commit
- [ ] PR description unchanged
- [ ] Labels and metadata unchanged

### Reasonable Performance

The second run should be faster:

- [ ] Skips operations that don't need repeating
- [ ] Logs indicate "already exists" or "no changes"
- [ ] API calls reduced (not re-fetching everything)

---

## Testing Failure Recovery

The real test is partial failure:

1. Run workflow
2. Manually interrupt at step N
3. Rerun from beginning
4. Verify clean completion without duplicates

```bash
# Simulate failure at step 3
./workflow.sh --fail-at-step 3 || true

# Rerun - should complete cleanly
./workflow.sh
```

---

## Common Test Failures

| Symptom | Likely Cause |
| --------- | -------------- |
| Duplicate PRs | Missing check-before-create |
| "Branch already exists" error | Not using `-B` flag or not checking first |
| Empty commit error | Not checking for changes before commit |
| Second run much slower | Re-doing work that should skip |
| Different end state | Non-deterministic operations |
