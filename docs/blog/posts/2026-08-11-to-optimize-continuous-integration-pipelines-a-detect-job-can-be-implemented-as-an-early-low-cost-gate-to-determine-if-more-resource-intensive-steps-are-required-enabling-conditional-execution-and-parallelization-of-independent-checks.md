---
title: Speeding Up CI: The 'Detect' Job Pattern
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

I still remember the sting of watching our core platform's build pipeline
grind through an expensive set of checks, consuming minutes of precious
compute, only to output: "No relevant changes found. Nothing to audit."
It was for a simple documentation change, a quick typo fix, and yet our
system performed a full cryptographic identity check, fetched private
reviewer data, and spun up a Go environment – all to confirm there was
nothing for its helm chart linter to do. Multiply that across dozens of
pull requests a day, and you quickly realize the hidden cost of unnecessary
CI work.
That frustrating moment was the catalyst for rethinking how we gated our most resource-intensive checks.

<!-- more -->

What that experience made clear was the need for a smarter, cheaper front
door for our pipelines. We developed what I've come to call the "detect"
job pattern. This pattern introduces a minimal, ultra-fast job early in
the CI workflow whose sole purpose is to determine *if* more comprehensive,
resource-heavy steps are actually required. If the detect job finds no
relevant changes, the subsequent expensive jobs are skipped entirely.
If it *does* detect relevant changes, it can even output artifacts that
enable parallel execution of independent follow-up checks.

For instance, in the scenario above, we transformed our single, monolithic
`config-validation` job into three distinct stages. First, a
`detect-config-changes` job simply performs a `git diff` to identify if any
files within our `platform-config` directory were modified. This job has
minimal setup: just a `checkout` and a `changed-files` scan. It's designed
to be blindingly fast. If no config-related files are touched, the job
exits successfully, and the pipeline effectively short-circuits.

!!! tip
    When designing a 'detect' job, relentlessly optimize for speed and minimal
    resource usage. The more lightweight your detect job, the greater the savings
    across your entire pipeline. Avoid external service calls, complex
    computations, or large artifact downloads. Its primary function is a quick
    "yes/no" or "here's what changed."

Crucially, if `detect-config-changes` *does* find modified `platform-config`
files, it generates a list of affected configuration roots. This list
becomes an output artifact. Subsequent jobs, `validate-config-syntax` and
`verify-config-integrity`, then depend on this `detect` job. They read its
output, focusing their efforts only on the relevant configurations. Moreover,
because `validate-config-syntax` and `verify-config-integrity` are
independent concerns, they can now run *in parallel*, each pulling the
necessary context from the `detect` job's artifact and performing their
specialized, more expensive checks (like spinning up that Go environment or
fetching private reviewer data). This pattern radically reduced our average
pipeline run time for non-config changes from several minutes to under
thirty seconds, saving significant developer time and compute costs.
