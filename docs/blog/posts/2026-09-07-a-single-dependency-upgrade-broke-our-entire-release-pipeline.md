---
title: A Single Dependency Upgrade Broke Our Entire Release Pipeline
date: 2026-09-07
authors:
  - mark
categories:
  - engineering
  - ci-cd
description: >-
  A dependency upgrade from v16 to v17 caused an ERESOLVE error, breaking our CI pipeline, prompting a review of our dependency management strategy.
slug: dependency-upgrade-broke-release-pipeline
---

The release build failed with a single, cryptic error: ERESOLVE. An automated
dependency bump, from version 16 to 17, had quietly violated a downstream peer
dependency, bringing our CI pipeline to a halt. This wasn't a complex feature merge
or a sweeping architectural change; it was a single, automated pull request that
looked like routine maintenance. That single commit, however, kicked off a day of
untangling a dependency conflict that threatened to delay a critical deployment.
It revealed a subtle but significant gap in how we managed our application's
dependency tree, forcing a deeper look at the trust we placed in our automated tooling.

<!-- more -->

## The Anatomy of a "Simple" Failure

It started, as these things often do, with a red build in our continuous integration
dashboard. The project was our core platform integration service, a critical piece of
infrastructure. The error itself was maddeningly opaque: `ERESOLVE unable to resolve
dependency tree`. The build logs showed the failure occurred during the `npm install`
step for our command-line utility, a helper tool bundled with the main service.
There were no obvious culprits in the recent commit history, just a few automated
dependency bumps from our Renovate bot. One of these was PR #291, which updated
our `graphql` package from version 16 to 17. On its own, this seemed harmless. The new
version was stable, and the changelog suggested no breaking changes that would affect
our direct usage.

## Unearthing the Peer Dependency Conflict

The problem wasn't in our direct code, but in the web of indirect, or transitive,
dependencies. Our command-line utility relies on `graphql-request`, a popular
client library. As it turned out, the latest version of `graphql-request` we were
using (`7.4.0`) had a strict peer dependency on `graphql`. It was explicitly coded
to work only with versions `14.x`, `15.x`, or `16.x`. When our automated tooling bumped
the top-level `graphql` dependency to `17.0.0`, it satisfied our *direct* dependency
requirement but violated the *peer* dependency requirement of `graphql-request`.
The `ERESOLVE` error was npm's way of telling us that it couldn't build a valid
dependency tree that satisfied these conflicting constraints. The release pipeline
was blocked.

## The Immediate Fix: A Strategic Reversion

The first priority was to get the pipeline green again. With a release pending, we
didn't have time for a prolonged investigation into whether `graphql-request` could
be safely upgraded or patched. The most direct path was to revert the change that
introduced the conflict. We opened a new pull request (#319) with a simple but crucial
change: we rolled `graphql` back from `^17.0.0` to `^16.0.0` in our `package.json`.
It felt like a step backward, but it was a necessary tactical retreat. The build
passed, and the release went out on time. The immediate crisis was averted, but the
incident left us with an uneasy feeling. Our process had a blind spot.

## Beyond the Hotfix: A More Resilient Strategy

A red build is a learning opportunity. This failure prompted a review of our entire
dependency management strategy. Relying solely on automated bumps for top-level
dependencies was clearly not enough. We needed a more nuanced approach that could
account for the complex interplay of a modern Node.js project's dependency graph.
We settled on a multi-layered strategy to prevent this class of problem from recurring.

## Layer 1: The Power of Pinning

The first change was to re-evaluate our use of semantic versioning ranges. While
using `^` (caret) is convenient for automatically getting minor and patch updates,
it was the direct cause of our issue. For a small set of absolutely critical
libraries, foundational frameworks like `graphql` or core HTTP clients, we moved to
pinning exact versions. For example, instead of `^16.0.0`, a `package.json` might specify `16.8.1`. This provides stability. The trade-off is that we no longer get automatic
patch updates for these pinned dependencies, which often include important security
fixes. We accepted this trade-off, creating a recurring manual task to review and
bump these pinned versions deliberately.

## Layer 2: Overrides as a Last Resort

What if we couldn't revert? Sometimes, you're stuck between a rock and a hard place:
one dependency needs a newer version of a package, while another needs an older one,
and neither can be changed. In these scenarios, a tool worth considering is `overrides`. Most modern package managers (like npm, pnpm, and Yarn with its `resolutions`
field) allow you to specify a required version for a transitive dependency.

!!! warning
    The `overrides` feature is a powerful tool, but it's also a dangerous one.
    You are essentially telling the package manager, "I know better than the library
    author." Use it as a temporary measure while you wait for an upstream fix,
    and document its purpose clearly. An uncommented override can become a maintenance
    nightmare a year down the line.

If we had been forced to use `graphql@17`, we could have added an `overrides` block
to our `package.json` to tell npm to use a specific, compatible version of a
sub-dependency, even if the library itself specified a different range.

```json
"overrides": {
  "graphql-request": {
    "graphql": "$graphql"
  }
}
```

This tells npm that `graphql-request` must use the same `graphql` version that
is installed at the project root.

## Layer 3: Enhancing CI with Deeper Validation

Our CI process was already running tests, but it wasn't explicitly validating
the integrity of the dependency tree itself. A recommended enhancement to the CI process is to add a step to validate the integrity of the dependency tree itself. For example, running `npm list` after `npm install` can check for any reported
issues. A more aggressive approach is to use a tool like `npm-check-updates` in a read-only mode to audit
for dependency drift and potential conflicts *before* they are even merged. This
acts as an early warning system, flagging pull requests from our automated tooling
that might introduce an `ERESOLVE` situation.

## A More Stable Future

The journey from a single `ERESOLVE` error to a multi-layered dependency strategy
was a lesson in the hidden complexities of modern software development. It reinforced
that stability isn't just about writing good code; it's also about managing the
ecosystem your code lives in. By combining strategic version pinning, the cautious
use of overrides, and proactive CI validation, we've built a more resilient
system, one that can embrace the benefits of automated dependency updates without
falling victim to their blind spots. It required more discipline, but the result
is a build process that is not only more stable but also more predictable.
