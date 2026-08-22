---
title: "Speeding Up CI: The 'Detect' Job Pattern"
date: 2026-08-11
authors:
  - mark
categories:
  - Continuous Integration
  - DevOps
  - Pipeline Optimization
description: >-
  I once watched a critical CI pipeline chew through resources for minutes,
  only to declare 'nothing to audit.' That's when I realized we needed a better gate.
slug: speeding-up-ci-the-detect-job-pattern
---

I still recall the sting of watching our build pipeline grind through a
costly set of checks. It burned minutes of compute. Then it just said:
"No relevant changes found. Nothing to audit." It was for a small doc
change, a quick typo fix. Yet our system ran a full identity check,
pulled private reviewer data, and spun up a Go setup. All that, to
confirm its helm chart linter had nothing to do. Multiply that across
dozens of pull requests a day, and the hidden cost of wasted CI work
adds up fast.
That moment pushed us to rethink how we gated our priciest checks.

<!-- more -->

That day made one thing clear: we needed a cheap front door for our
pipelines. So we built what I now call the "detect" job pattern. It is
a small, fast job that runs early in the CI flow. Its one job is to
check if the big, costly steps are even needed. If the detect job
finds no relevant changes, it skips the costly jobs. If it does find
changes, it can output data that lets the follow-up checks run in
parallel.

We used this on the case above: one big check became a fast detect
step, feeding parallel jobs that ran only on the parts that changed.

!!! tip
    When you build a 'detect' job, push hard for speed and low resource
    use. The lighter your detect job, the more you save across the whole
    pipeline. Skip external calls, heavy logic, or large file pulls. Its
    one job is a quick "yes or no", or a short list of what changed.

The payoff was fast. Average run time for non-config changes fell from
several minutes to under thirty seconds. Costly checks now run only
when the change calls for them.

## Related

- **[Change Detection](../../build/release-pipelines/change-detection.md)** - Implementing this pattern with `tj-actions/changed-files`, cascade dependencies, and conditional job execution
