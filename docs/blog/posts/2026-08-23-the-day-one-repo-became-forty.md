---
title: The Day One Repo Became Forty
date: 2026-08-23
authors:
  - mark
categories:
  - gitops
  - kubernetes
  - devops
description: >-
  One repo built for a single cluster grew into config for forty. Here's the week
  copy-paste caught up with us, and how we finally trusted what was running.
slug: the-day-one-repo-became-forty
---

# The Day One Repo Became Forty

The request landed on a Monday: a new team needed a cluster, live by Friday. That
same week, an alert traced back to cluster twelve, quietly running a policy nobody
on the team remembered setting. Forty clusters in, and I could not say with a
straight face what any single one of them was actually running.

<!-- more -->

!!! note "How one repo becomes forty"
    Nobody plans this. It happens one reasonable choice at a time, until the file
    tree tells a very different story than the one you remember agreeing to.

It started small, the way these things do. One repository held the manifests for
one cluster. When a second cluster arrived, we copied the folder, tweaked a few
values, and called it done. When a third showed up, we did it again. Nobody
decided to build a system this way. Each copy was just the fastest path to
shipping that week's request.

By cluster ten, the repo had a shape, but not one you could explain out loud. Some
folders had an override that others didn't. A couple carried a setting from a
one-off incident two years back, still there, still silently active, because
nobody wanted to be the one who removed it and broke something they didn't fully
understand. Knowledge about which cluster ran which variant lived in a handful of
heads, not in any file you could point to.

That's the part that stung. It wasn't that the copy-paste was ugly. It was that
nobody could answer a simple question with confidence: what is actually deployed
on cluster twelve, right now, and why does it differ from cluster eleven. Every
answer started with "I think" and ended with someone opening a terminal to check.
The incident that week was small. The pattern behind it wasn't.

Our first instinct was to fix it with better documentation. Write down which
cluster had which override, and why. Keep a table. Review it every quarter. It
took about a day of trying before the real problem surfaced: documentation
describes copy-paste, it doesn't stop it. The next cluster onboarded next month
would still be a copy of whatever folder looked closest, drifting the same way
every folder before it had drifted.

The actual shift was smaller than expected and harder to accept. Stop maintaining
forty near-identical folders. Define the desired state once, as a template, and
let generator-driven tooling produce the per-cluster output from a single source.
A new cluster stopped being a folder someone hand-built from the nearest example.
It became one entry in a list, one label on a registered cluster, or one file
dropped into a Git-driven fan-out. The full mechanics of that shift, generators,
sync policy, and the guardrails that keep it from deleting things it shouldn't,
are in the article linked below.

Onboarding a cluster now takes an afternoon. That's the part people notice first.
The part that actually changed how the team works is quieter: nobody has to
"just know" which override belongs where anymore, because there isn't a pile of
overrides to know. What's in Git is what's running, on cluster one and on cluster
forty, and for the first time in a long while, I can answer that incident
question without opening a terminal to check.

## Related

- [GitOps Multi-Cluster Delivery with ArgoCD ApplicationSets](../../patterns/architecture/gitops-applicationset/index.md) - the templating and generator pattern that ended the copy-paste sprawl this post describes.
