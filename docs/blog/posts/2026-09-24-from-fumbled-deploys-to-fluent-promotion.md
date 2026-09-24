---
title: From Fumbled Deploys to Fluent Promotion
date: 2026-09-24
authors:
  - mark
categories:
  - Infrastructure
  - GitOps
  - CI/CD
description: >-
  Routine deployment failed staging due to a manual, incorrect image tag. This incident sparked our journey to a systematic, automated promotion process.
slug: from-fumbled-deploys-to-fluent-promotion
---

A Tuesday morning, a routine deployment resulted in a staging
environment outage. The alert storm was immediate, but the
root cause was maddeningly simple. A new version of a core service had been deployed, but it was pointing to a production dependency, not its staging counterpart. The culprit wasn't a complex bug
or a subtle integration failure, but a single, incorrect image
tag in a Kubernetes manifest. This was applied manually during
a hurried deploy. It was a slip that kickstarted our journey
from ad-hoc updates to a truly systematic promotion process
for our infrastructure components.

<!-- more -->

That incident was a symptom of a larger disease. Our process
for moving software from one environment to another was broken.
It was a chaotic mix of manual `kubectl` commands, informal
Slack messages, and institutional knowledge locked away in the
heads of a few senior engineers. We had no single source of
truth to tell us what version of which component was running
in `dev`, let alone `staging`.

## The Anatomy of a Failure

When we dug into the post-mortem, the findings were unsettling
but not surprising. The engineer performing the deployment
had copied a manifest from their local machine. It was an
older version, and in the rush to get the update out, no one
had caught the hardcoded production endpoint. There was no
formal review, no automated check, no audit log beyond a
shell history. We were treating our infrastructure like a
mutable, handcrafted artifact, and it was costing us dearly
in stability and developer confidence. We needed to treat our
infrastructure configuration with the same rigor as our application
code.

## The Promise of Git as Truth

The core principle we rallied around was simple: Git, and only
Git, should be the source of truth for the state of our
infrastructure. If a change wasn't in a commit, it didn't
exist. This meant an end to manual `kubectl apply` or `helm
upgrade` commands executed from an engineer's laptop. Every
change, from a version bump to a configuration tweak, would
have to go through a pull request, get reviewed, and be merged
by our GitOps controller. This wasn't just about adding a
safety check; it was a fundamental shift in our operating
model. The repository would become the declarative description
of our running systems.

## Kustomize Overlays: Our Environment Layers

To implement this, we turned to Kustomize. Its overlay system
provided the perfect model for managing our environment-specific
configurations without duplicating code. We structured our
platform repository with a `base` directory containing all
the standard, shared manifests for a given component. Then,
we created `overlays` for each environment: `dev`, `qac`,
and `staging`.

These overlays are intentionally thin. They don't contain a
full copy of the component's manifests. Instead, they only
specify the patches or values that are *different* for that
specific environment. For version promotions, this is incredibly
powerful. The `dev` overlay's `kustomization.yaml` might specify
version `v1.2.1` of our Logging Service, while the `staging`
overlay points to the stable `v1.2.0`.

!!! note
    A key lesson here was to aggressively enforce the thinness of
the overlays. The goal is to only specify the delta between
the base and the environment. If you find yourself copying
entire manifests into an overlay, you're losing the benefits
of inheritance and increasing your maintenance burden.

## The Promotion Commit

With the structure in place, we needed a mechanism to actually
*perform* a promotion. The answer was a specific, structured
commit message format. When a component was ready to be
promoted, an engineer would open a pull request that changed
a single line in the target environment's `kustomization.yaml`
file--the image tag.

The pull request, and the resulting merge commit, followed a strict convention:

`chore(promote): opentelemetry-collector 0.169.0 → DEV`

This format isn't just for human readability. It's a machine-readable instruction. It clearly states the component being changed, its new version, and the target environment. The PR number, like `#1138` in our history, links this infrastructure change directly back to the discussion and approval process.

## Automating the Sync

Our GitOps controller, a continuous delivery tool that constantly
monitors the state of our repositories, is configured to watch
for these merges. When a commit like `chore(promote): reloader
2.2.15 → STG (#1141)` hits the main branch, the controller
immediately recognizes a change in the desired state for our
staging environment. It automatically fetches the updated manifests
from the `overlays/stg` directory, builds the final YAML using
Kustomize, and applies it to the Kubernetes cluster. The manual,
error-prone step that caused our initial outage was now completely
automated, driven by a peer-reviewed Git commit.

## From Hours to Minutes

The results of this new system were transformative. A process
that used to take hours of manual coordination, with a high
risk of error, now takes minutes. An engineer opens a PR,
it gets reviewed, and upon merge, the change is live in the
target environment. The Git history has become a perfect,
immutable audit log of every change ever made to our platform.
We can see exactly who promoted what, when they did it, and
what discussion happened in the associated pull request.

## Confidence in Our Tooling

More than just the speed, the new process gave us confidence.
We no longer had to second-guess the state of an environment.
We could trust that what was in Git was what was running in
the cluster. This freed up our engineers to focus on building
features, not on firefighting broken deployments. When we
promote `trivy 0.35.0` to staging, we know that's exactly
the version that will be deployed, because the commit itself
is the deployment instruction.

## What Lies Ahead

This journey has been incredibly successful for our non-production environments. The next logical step, which we are actively working on, is extending this pattern to our production environment. This requires an even higher level of rigor, with more sophisticated automated checks, canary deployments,
and automated rollback capabilities. But the foundation is solid. By treating our infrastructure as code and making Git the unimpeachable source of truth, we've built a system that is not only more efficient, but fundamentally more reliable.
