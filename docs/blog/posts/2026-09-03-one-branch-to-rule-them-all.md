---
title: One Branch to Rule Them All
date: 2026-09-03
authors:
  - mark
categories:
  - engineering
  - go
  - automation
description: >-
  Several automated dependency update pull requests, each conflicting. The path to a clean merge wasn't through them, but around them.
slug: one-branch-to-rule-them-all
---
The queue held several pull requests from our dependency bot, all targeting the same `go.mod` file
in our primary diagnostics service. three minor version bumps and two that were simple hash updates. Several sets of merge
conflicts. Each PR was a simple, isolated, and technically correct update, yet together they
formed a tangled mess that blocked the release pipeline.

<!-- more -->

## The Promise of Automation

Automated dependency management is a cornerstone of modern software hygiene. We rely on a bot
we call "Renovate" to scan our repositories, find outdated dependencies, and open pull requests
with the latest versions. In theory, this process is seamless: a new version is released,
Renovate opens a PR, CI runs, a human approves, and the system is updated. It’s a clean, steady
drumbeat of proactive maintenance that prevents security vulnerabilities and keeps our stack current.

For months, this system worked beautifully. A PR would appear, it would be green, and we would
merge it. The process was so smooth it became background noise, a chore handled entirely by
our automation.

## The Friction of a Noisy System

The trouble began when the volume of updates increased. Our diagnostics tool, a critical
Go-based command-line interface for our platform, has a moderately complex dependency tree.
One morning, we found not one, but several pending PRs from Renovate for it. One updated our cloud
provider's monitoring library. Another bumped our internal platform abstraction library.
A third and fourth targeted different Google client libraries. Another updated another common utility.

Individually, these were trivial. `v1.29.0` to `v1.30.0` here, `v0.4.0` to `v0.4.2` there. But
because Renovate creates a separate branch and PR for each individual dependency update, they
were all based on the same `main` branch. When the first one was hypothetically merged, the
other four would immediately have merge conflicts. The `go.mod` and `go.sum` files are
notorious for this. Trying to rebase them in sequence became a frustrating exercise in
resolving the same conflicts again and again.

We were spending more time managing the bot's pull requests than we would have spent doing the
updates manually. The automation, intended to reduce toil, had become the primary source of it.

## The Brute-Force Rebase That Wasn't

The initial instinct was to just muscle through it. Pick an order and start rebasing. I started
with PR #445, the update for the Google API client. Then I tried to rebase PR #454, the platform
library update, on top of it.

The familiar, dreaded lines appeared, indicating a merge conflict in `ci/diagnostics/go.mod`.

I opened the file. Go's module system is explicit and declarative, which is a strength, but it
makes merges a headache. Do you take the version from `HEAD` or the incoming branch? Which
`replace` directives are still relevant? The `go.sum` file, with its cryptographic hashes
for every known version of every direct and indirect dependency, was even worse. Resolving
conflicts felt like performing surgery with a butter knife. After 15 minutes of untangling
the first rebase, I knew this wasn't the way. Applying the next three PRs would just repeat
the problem, compounding the complexity each time.

## The Simple, Obvious Insight

Staring at the several conflicting branches, a different thought emerged. The bot's branches weren't
precious. They were suggestions. The important thing wasn't *preserving the bot's work*; it was
*accomplishing the updates*.

What if I just ignored the bot's branches entirely?

The goal was to get all several dependencies updated. The several PRs represented the desired end state
for each dependency, but not the path to get there. The actual pattern was much simpler: define
the target state directly and let Go's tooling do the hard work.

## The One-Branch Pattern

I created a new, single branch off `main` to consolidate the updates. Then,
I systematically went through the several pull requests, not to merge them, but simply as a reference.

For each dependency, I noted the highest version being proposed across all the PRs.

- `cloud.google.com/go/monitoring`: `v1.30.0`
- `our-internal/platform-lib-go`: `v0.4.2`
- `google.golang.org/api`: `v0.292.0`
- And so on...

With this list, I manually edited my local `go.mod` file, changing the version numbers for those
specific `require` lines. I didn't touch anything else. I saved the file.

Then came the magic. I ran the `go mod tidy` command.

The Go toolchain sprang to life. It looked at my `require` block, calculated the complete
dependency graph, and resolved all the transitive dependencies. It pruned unused entries from
`go.sum` and added the necessary hashes for the new versions. There were no conflicts to
resolve because I wasn't merging two competing histories. I was just declaring a new state and
letting the tooling enforce it. The entire process took less than several minutes.

!!! tip "When to Use This Pattern"
    This approach is ideal for batching multiple, non-breaking minor or patch version updates
    that are causing merge conflicts. For major version bumps (`v1.x` to `v2.x`), which often
    contain breaking API changes, a dedicated branch and a more careful, individual migration
    is still the safest path.

## Verification and Completion

Of course, letting the tooling resolve the graph is only half the battle. The code still has to
build and pass its tests. The next step was crucial: ensuring everything compiled and all tests passed.

Everything compiled. All tests passed. The combined updates were compatible, just as the bot had
individually determined. The problem was never the code; it was the workflow.

With a single commit, I had accomplished what several conflicting PRs could not. I pushed my one
branch and opened a new pull request, explicitly superseding the bot's several open PRs. The
change was clean, the history was linear, and the CI pipeline was green. We closed the bot's
noisy PRs and merged the one clean, consolidated update.

## An Efficient Anti-Pattern?

It feels slightly wrong to manually intervene in a process that's supposed to be fully
automated. But this isn't about rejecting automation; it's about applying it intelligently.
The bot is an excellent *detector*. It finds outdated dependencies with perfect fidelity.
It’s just not a great *integrator* when update frequency is high.

By treating the bot's PRs as notifications rather than strict directives, we reclaim the
integration step. This "manual" consolidation pattern is, ironically, more efficient. It
takes a developer a few minutes once a week, rather than forcing them to constantly untangle
merge conflicts in a piecemeal fashion. It batches low-risk changes into a single, clean
update, reducing noise and letting everyone focus on more complex problems. The automation
still handles the discovery; the human handles the final, trivial-but-nuanced integration.
It’s the best of both worlds.
