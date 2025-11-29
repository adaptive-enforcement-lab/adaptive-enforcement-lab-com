---
date: 2025-11-27
authors:
  - mark
categories:
  - CI/CD
  - Resilience
  - Engineering Patterns
slug: idempotent-automation-why-reruns-shouldnt-scare-you
---

# Idempotent Automation: Why Reruns Shouldn't Scare You

Your workflow failed at step 47 of 50. Do you fix the issue and rerun from the beginning, or do you manually complete the remaining steps?

!!! failure "The Nervousness Test"

    If that question makes you nervous, your automation isn't idempotent. And that's a problem.

This post shares the journey to making reruns boring. For the full technical deep-dive, see the [Idempotency Pattern Guide](../../developer-guide/engineering-practices/patterns/idempotency/index.md).

<!-- more -->

---

## The Scenario That Started It All

It was a Friday afternoon. A file distribution workflow syncing CONTRIBUTING.md to 40 repositories had failed at repository 37. Rate limiting.

Three options presented themselves:

1. **Rerun from the beginning** - But would it create duplicate PRs for the 36 repos that succeeded?
2. **Manually complete the remaining 4** - Doable, but tedious
3. **Wait until Monday** - The coward's choice

I chose option 1. And watched in horror as the workflow created 36 duplicate PRs.

!!! quote "The Learning Moment"

    That afternoon taught me more about idempotency than any documentation ever could.

---

## The Fix Was Embarrassingly Simple

One conditional check before creating PRs:

```bash
EXISTING=$(gh pr list --head "$BRANCH" --json number --jq 'length')
if [ "$EXISTING" -eq 0 ]; then
  gh pr create --title "Automated update" --body "From central repo"
else
  echo "PR already exists, skipping creation"
fi
```

That's it. Check if it exists before creating it.

But that single fix led to a rabbit hole. What about the branch creation? The commits? The push? Each operation needed its own idempotency guard.

---

## The Rabbit Hole

The more I looked, the more I found:

- **Branch operations** needed force-reset to handle diverged state
- **Change detection** was using `git diff` which [doesn't see untracked files](./2025-11-26-git-diff-lies.md)
- **Commits** failed with "nothing to commit" on clean reruns
- **Pushes** needed `--force-with-lease` to handle rebased branches

Each fix was simple. The challenge was finding them all.

!!! tip "The Full Breakdown"

    See [Implementation Patterns](../../developer-guide/engineering-practices/patterns/idempotency/patterns/index.md) for the five patterns that emerged from this work.

---

## The Payoff

Three weeks later, the same workflow failed again. Different repository, different error. Network timeout.

This time, I clicked "Re-run jobs" and went to lunch.

When I came back, everything was green. The 39 successful repos had detected "no changes needed" and skipped. The failed repo had retried and succeeded.

No duplicates. No manual cleanup. No fear.

---

## When It's Not Worth It

Not every workflow needs this treatment. A one-off migration script? Just run it carefully. A local development tool? Optimize for speed, not resilience.

The [Decision Matrix](../../developer-guide/engineering-practices/patterns/idempotency/decision-matrix.md) helps calibrate where to invest. The short version:

- **High failure risk + High recovery cost** = Full idempotency
- **Low failure risk + Low recovery cost** = Don't bother

---

## The Cliffhanger

There's one thing I haven't solved yet: caches.

What happens when your idempotent workflow depends on a cache that expired? Or a cache key that changed? The workflow that "worked fine on rerun" might fail spectacularly when the cache misses.

!!! question "The Cache Test"

    If you deleted all caches and reran your workflow, would it still produce the same result?

That's the next frontier. For now, see [Cache Considerations](../../developer-guide/engineering-practices/patterns/idempotency/caches.md) for the traps I've identified.

---

## Start Here

If you're dealing with flaky reruns:

1. Read [Pros and Cons](../../developer-guide/engineering-practices/patterns/idempotency/pros-and-cons.md) to understand the tradeoffs
2. Score your workflow with the [Decision Matrix](../../developer-guide/engineering-practices/patterns/idempotency/decision-matrix.md)
3. Apply the relevant [Implementation Patterns](../../developer-guide/engineering-practices/patterns/idempotency/patterns/index.md)
4. [Test it](../../developer-guide/engineering-practices/patterns/idempotency/testing.md) by running twice

---

*Your workflow failed at step 47. You fixed the bug, clicked rerun, and went to lunch. When you came back, everything was green. That's the power of idempotent automation.*
