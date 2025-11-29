---
title: Pros and Cons
description: >-
  The tradeoffs of investing in idempotent automation.
  Benefits, drawbacks, and what to watch out for.
---

# Pros and Cons

Idempotency isn't free. Understanding the tradeoffs helps you decide where to invest.

## At a Glance

| Pros | Cons |
|------|------|
| [Safe Reruns](#safe_reruns) - Click rerun, walk away | [Implementation Complexity](#implementation_complexity) - Every op needs guards |
| [Partial Failure Recovery](#partial_failure_recovery) - Matrix jobs retry cleanly | [Performance Overhead](#performance_overhead) - Extra API calls add up |
| [Simplified Debugging](#simplified_debugging) - Debug without changing state | [Hidden Failures](#hidden_failures) - Silent skips mask real errors |
| [Scheduled Job Safety](#scheduled_job_safety) - Handle duplicate triggers | [State Consistency Challenges](#state_consistency_challenges) - Detecting state is hard |
| [Reduced Cognitive Load](#reduced_cognitive_load) - System tracks state | [Not Always Possible](#not_always_possible) - Some ops can't be idempotent |

---

## Pros

### Safe Reruns

The primary benefit. When something fails, you click "Re-run jobs" and walk away. No fear. No manual state inspection. No "did it already do X?" questions.

```yaml
# Safe to rerun: checks before acting
- name: Create PR if not exists
  run: |
    EXISTING=$(gh pr list --head $BRANCH --json number --jq 'length')
    if [ "$EXISTING" -eq 0 ]; then
      gh pr create --title "Update" --body "Automated update"
    else
      echo "PR already exists, skipping creation"
    fi
```

### Partial Failure Recovery

Matrix jobs processing 40 repositories. Job 37 fails due to rate limiting. With idempotent operations, you rerun the entire matrix. The 36 successful repos detect "no changes needed" and skip. Job 37 retries and succeeds.

Without idempotency, you'd need to figure out which repos succeeded, exclude them, and run only the failures.

### Simplified Debugging

When operations are idempotent, you can add logging, rerun, and see exactly what happens without changing state. Debug freely.

```yaml
- name: Debug and retry
  run: |
    set -x  # Enable debug output
    # Safe to rerun with debugging enabled
    ./idempotent-script.sh
```

### Scheduled Job Safety

Cron-triggered workflows might run twice due to GitHub Actions quirks, overlapping schedules, or manual triggers during scheduled windows. Idempotent operations handle this gracefully.

### Reduced Cognitive Load

Engineers don't need to track "did this already run?" or maintain mental models of partial state. The system handles it.

---

## Cons

### Implementation Complexity

Every operation needs guards. Create-if-not-exists. Update-or-create. Check-before-act. This adds code, conditions, and potential bugs in the guard logic itself.

```yaml
# Simple but not idempotent
- run: git commit -m "Update"

# Idempotent but more complex
- run: |
    if [ -n "$(git status --porcelain)" ]; then
      git commit -m "Update"
    else
      echo "No changes to commit"
    fi
```

### Performance Overhead

Checking "does this already exist?" before every operation adds API calls, database queries, or filesystem checks. For high-volume operations, this overhead accumulates.

```yaml
# Fast but not idempotent
- run: gh pr create ...

# Slower but idempotent (extra API call)
- run: |
    if ! gh pr list --head $BRANCH --json number | jq -e 'length > 0'; then
      gh pr create ...
    fi
```

### Hidden Failures

!!! warning "Silent Skips Can Mask Real Failures"

    When operations silently skip because "already done," you might miss actual failures. Did the PR not get created because it exists, or because the creation failed and the error was swallowed?

```yaml
# Dangerous: masks errors
- run: |
    gh pr create ... || echo "PR might already exist"

# Better: explicit state checking
- run: |
    if gh pr list --head $BRANCH --json number | jq -e 'length > 0'; then
      echo "PR exists"
    else
      gh pr create ...  # Fails loudly if creation fails
    fi
```

### State Consistency Challenges

Idempotency assumes you can reliably detect current state. But what if:

- The PR exists but was closed?
- The file exists but has wrong content?
- The branch exists but diverged?

Naive idempotency checks might skip operations that actually need to run.

### Not Always Possible

!!! danger "Inherently Non-Idempotent Operations"

    Some operations can't be made idempotent:

    - Sending notifications (can't unsend)
    - Incrementing counters (can't detect if already incremented)
    - Time-sensitive operations (state changes between check and act)
