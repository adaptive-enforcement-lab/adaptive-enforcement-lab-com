---
title: The 15-Minute Performance Test
date: 2026-09-13
authors:
  - mark
categories:
  - engineering
  - automation
  - ci-cd
description: >-
  Learn how to implement a 15-minute performance test in your CI/CD pipeline.
  Catch regressions early with automated, ephemeral production-scale environments.
slug: the-15-minute-performance-test
---

The pull request was small, a single-line change to a data processing job.
Yet the CI pipeline had just spun up a complete, isolated, production-scale
environment, loaded it with terabytes of realistic data, and was now running
a full performance benchmark. Fifteen minutes later, it posted a comment with
the results: latency down by 5%, CPU usage unchanged, and, most importantly,
the estimated monthly cost of the change was a rounding error. The environment
then vanished as if it had never existed. This automated, ephemeral world was
new for us, and it was already changing everything.

<!-- more -->

This wasn't a "nice-to-have" engineering project. It was born from a series
of painful, slow, and unreliable performance-testing cycles. Our previous
approach, a shared, manually-managed staging environment, was a constant
source of friction. This is the story of how we moved from that state of
chaos to a fully automated system that gives us performance and cost
feedback on every single change.

## The Tyranny of the Shared Staging Environment

For years, our process for performance and scale testing was informal and
brittle. We had a single, persistent staging environment, a pale imitation
of our production setup. When a developer needed to test the impact of their
changes, they had to "book" a time slot, manually deploy their branch,
and hope that no one else was running a conflicting test.

More often than not, this didn't work. Tests would be contaminated by other
developers' work, by leftover data from previous experiments, or by
configuration drift that had accumulated over months. A sudden performance
drop might be caused by your change, or it might be because someone else was
running a massive backfill at the same time. You could never be sure. The
result was that we only ran these tests for the largest, riskiest changes,
and even then, the results were suspect. We were flying blind.

## The Epiphany: Environments as Cattle, Not Pets

The turning point came during a post-mortem for a nasty performance
regression that made it all the way to production. It had been introduced by
a seemingly innocuous change weeks earlier. The developer had tried to run a
performance test, but the staging environment was "in use," so they skipped
it. We spent the better part of a week tracking it down.

During the review, someone said, "What if we could give every developer
their own private, disposable staging environment?" The idea sounded
impossibly expensive and complex. But the more we talked about it, the more
we realized that the cost of *not* doing it was far higher. The cost of
emergency rollbacks, of wasted developer time, and of customer-facing
outages, it was all adding up. We decided to treat our test environments like
cattle, not pets: created on-demand from a repeatable script and disposed of
without a second thought.

## Our First Ephemeral Environment: The "v1"

Our initial goal was simple: create an automated job that could spin up an
environment, run a single, well-defined benchmark, and then tear it down.
We chose one of our most critical data-ingestion workflows as the first
target. The benchmark would measure the time it took to load a standardized
dataset.

We defined the entire environment as code in a set of YAML files, stored in
our operations repository. A change to our CI pipeline configuration
triggered a workflow that would:

1.  Provision a new Kubernetes namespace.
2.  Deploy the data platform services into that namespace using their standard
    Helm charts.
3.  Run a Kubernetes Job that executed our data loader tool to ingest the test data.
4.  Scrape the duration and resource usage metrics from the job.
5.  Destroy the namespace.

The first successful run was a breakthrough. It took about 30 minutes, which
was slow, but it was repeatable and isolated. We had a baseline. Commits from
this time, with messages like `chore(cd): PLAT-823 start qac sandbox-v1 for db/index size comparison`,
mark this initial, crucial step.

## Measuring What Matters: Data Footprint Analysis

One of the first things we learned was that performance wasn't just about
speed. A change could make a process faster but dramatically increase the
amount of data stored, driving up our cloud storage bills. We'd been burned
by this before, when a change to an indexing strategy caused a 10x explosion
in storage size that went unnoticed for a month.

Our "v2" of the ephemeral environment added a new step to the process. After
the data-loading benchmark completed, another job would connect to the
database and run a query to measure the on-disk size of the newly created
indexes and tables. This gave us a second, critical metric to track: the data
footprint. Now, a PR that significantly increased the storage cost of our
data would be flagged automatically. The commit `chore(cd): PLAT-823 stop qac
sandbox-v1 after size comparison` shows the evolution, where we explicitly
started and stopped environments just for this specific analysis.

!!! note
    We found that measuring the data footprint was just as important as
    measuring latency or CPU. A small code change can have a massive impact
    on storage costs, and catching those changes before they hit production
    is a huge win.

## The "v2" Environment: Adding Realism and Speed

The "v1" environment was a great proof-of-concept, but it was slow and used
a sanitized, generic dataset. To get a more accurate signal, we needed to
test with realistic, production-like data. This led to the development of our
"v2" environment.

The key innovation was a new "sanitizer" service. This service could take a
recent snapshot of our production database, anonymize all personally
identifiable information (PII) according to our internal data-handling
policies, and make it available to our ephemeral test environments. This was
a game-changer. Suddenly, our performance tests were running against data with
the same scale and cardinality as production.

We also worked hard to optimize the environment startup time. We pre-baked our
Docker images, optimized our Helm charts for a quick startup, and fine-tuned
our resource requests to get pods scheduled faster. This brought the average
environment creation time down from over 20 minutes to under five. The commits
`chore(cd): PLAT-823 start qac sandbox-v2 for contovistaloader load` and
`chore(cd): PLAT-823 stop qac sandbox-v2 after contovistaloader load benchmark`
reflect this more mature, faster, and more targeted benchmark-and-destroy cycle.

## Integrating with the CI/CD Pipeline

The final piece of the puzzle was making this entire process seamless for
developers. We didn't want them to have to think about it. We used our CI/CD
platform's API to integrate the ephemeral environment workflow directly into
our pull request lifecycle.

When a developer opens a PR, a webhook triggers the pipeline. The pipeline
runs the standard unit and integration tests first. If they pass, it then
provisions the ephemeral environment, runs the performance and data footprint
benchmarks, and posts the results as a comment on the PR. It looks something
like this:

## Performance Test Results

- **Latency:** `5.21s` (9% improvement) ✅
- **Data Footprint:** `10.2 GB` (1% increase) ✅
- **Estimated Cost Impact:** `+$50/month` ✅

This gives the developer and the reviewer immediate, quantitative feedback
on the non-functional impact of the change. It transforms the conversation
from "I think this might be slow" to "This is 12% slower and will cost us an
extra $1,000 a month."

## The Payoff: Catching Regressions Before They Happen

The impact of this system has been profound. We now catch the vast majority
of performance and data-size regressions before they're merged. The feedback
loop is measured in minutes, not weeks. Developers can iterate on performance
improvements with confidence, knowing they'll get immediate, reliable data.

The system isn't perfect. We still have work to do to support more types of
benchmarks and to reduce the cost of the environments further. But it has
fundamentally changed our engineering culture for the better. We're no longer
afraid of performance testing; it's just another part of our daily workflow.

## Building Your Own Ephemeral Test Pipeline

Starting this journey can seem daunting, but it doesn't have to be. You can
start small. Pick a single, critical workflow and a single metric you want
to improve. Automate the process of creating an environment for just that
one test. Even a simple, slow, and limited ephemeral environment is better
than a shared staging server. Once you have that first building block, you can
iterate, improve, and expand its capabilities over time. The investment will
pay for itself many times over in the form of fewer production incidents,
more efficient engineers, and a better product for your users.
