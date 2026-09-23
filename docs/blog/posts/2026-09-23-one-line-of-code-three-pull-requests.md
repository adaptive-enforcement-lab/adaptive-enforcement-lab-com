---
title: One Line of Code, Three Pull Requests
date: 2026-09-23
authors:
  - mark
categories:
  - engineering
  - automation
  - devops
description: >-
  Our new certificate tooling passed tests, but staging deployment revealed a critical flaw that would have taken down production.
slug: one-line-of-code-three-pull-requests
---
A new version of our internal certificate tooling passed all its tests, but deploying it to our staging environment
revealed a critical, deep-seated flaw. Under heavy load, it was mismanaging memory, and a slow, creeping leak
threatened to take down the entire node. It was the kind of bug that unit tests would never catch, but that
our fully-provisioned staging environment, a near-perfect mirror of production, was designed to expose.
The automated promotion failed, the alerts fired, and a production outage was averted.

<!-- more -->

This wasn't a story of heroic, late-night debugging, but the quiet, satisfying success of a system working exactly
as intended. That failed promotion was the output of a deliberate engineering pattern we had built to solve one
of the most persistent problems in software delivery: managing distinct software component versions across
multiple deployment environments. We had moved from a world of manual promotions and hopeful checklists to a fully
automated, Git-driven workflow where every change is explicit, audited, and propagated by machines.

## The Specter of Configuration Drift

Before we implemented this system, our environments were in a constant state of low-grade entropy.
A developer might deploy a specific version of a microservice to staging for a quick test.
A hotfix might be applied directly to the production environment to resolve an urgent incident.
Each of these well-intentioned, pragmatic actions chipped away at the integrity of our environments.
Staging no longer mirrored production, making pre-deployment validation unreliable.
We were losing the ability to answer a simple, critical question: "What exact version of each component is
running in each environment?" The answer was scattered across deployment scripts, command histories, and
tribal knowledge.

## Git as the Single Source of Truth

The foundational decision was to make our Git repository the absolute, unimpeachable source of truth for the state of our environments.
If it wasn't in `main`, it wasn't real. This meant that the desired state of every environment, from the lowest
development sandbox to the highest production tier, had to be declaratively defined in code.

For our Kubernetes-based infrastructure, this took the form of simple `values.yaml` files. We created a directory structure that reflected our environment topology:

```text
├── cd/
│   ├── stg/
│   │   └── values.yaml
│   ├── prd/
│   │   └── values.yaml
│   └── ops/
│       └── values.yaml
```

Inside each `values.yaml`, we defined the exact version of each deployable component for that specific environment. A change to the running software could only be achieved by changing one of these files.

## A Promotion Is Just a Pull Request

With the state defined in Git, the act of "promoting" a software version from one environment to the next
became a simple matter of updating a text file. We built a small bot that understood our environment
hierarchy (STG → PRD → OPS). When a change was merged to the `values.yaml` for a lower environment, the bot
would automatically open a pull request to apply the same version change to the next environment up the chain.

This is why a single component update now results in a cascade of clean, predictable pull requests. A developer updates the `private-pki-operator` in staging, and moments after their PR is merged, they see a new one, authored by our bot:

> `chore(promote): private-pki-operator 0.1.19 → PRD`

This gives us a crucial, human-in-the-loop checkpoint. The promotion to production isn't a foregone conclusion; it's a reviewable code change that requires explicit approval from the service owners.

## The End of the Manual Hotfix

This GitOps-centric workflow forces a discipline that was previously difficult to enforce. The concept of a "manual hotfix" to a running environment is now impossible. To change a running system, you must go through the process: open a pull request, get it reviewed, and merge it.

!!! warning
    A GitOps workflow is intolerant of exceptions. The moment you bypass the process with a manual `kubectl apply`
    or a direct configuration change on a server, you have invalidated your source of truth. Guardrails like
    pre-commit hooks and branch protection rules are essential, but cultural adoption is the most powerful
    enforcement mechanism.

This process isn't about adding bureaucracy; it's about ensuring survivability and auditability. When an incident occurs, we don't need to guess what changed. The Git history provides a perfect, immutable log of every modification made to the system, who approved it, and when it was deployed.

## Staging as a Real Production Gateway

Our opening story about the memory leak highlights the renewed importance of the staging environment.
Because we can now trust that staging is an exact replica of production in terms of component versions,
we invest heavily in making it a high-fidelity environment. It receives the same traffic patterns
(anonymized, of course) and is subject to the same automated scaling policies and load. When a change
passes muster in staging, we have a very high degree of confidence that it will perform identically in production.

## Making Rollbacks Boring

The same mechanism that powers our promotions makes rollbacks a non-event. If a newly promoted version proves to be unstable in production, the recovery process isn't a frantic series of commands. It's simply a matter of reverting the pull request that initiated the promotion.

`git revert MERGE_COMMIT_SHA`

This single command triggers the exact same automated deployment pipeline, but this time it's deploying the
last known good version. The system declaratively converges the running state back to what the `values.yaml`
file specifies. It’s fast, safe, and, most importantly, boring.

## From Components to Platforms

We started this journey by managing the versions of a single microservice, the "private-pki-operator." But the pattern quickly scaled. Today, we manage entire platforms this way. The commit history for our "pki-platform" repository is a clean, linear series of bot-authored promotions for multiple components,
each moving in lockstep through the environments:

- `chore(promote): private-pki-operator 0.1.19 → PRD`
- `chore(promote): cert-manager-extensions 1.10.1 → PRD`

This ensures that the entire collection of services that make up the platform is versioned and promoted as a coherent, tested unit.

## A System That Builds Trust

Leveraging automated configuration management wasn't just a technical upgrade. It was a cultural one.
It replaced uncertainty with clarity, and manual toil with automated discipline. By encoding our promotion
process into a system that is visible, reviewable, and repeatable, we built a powerful engine for managing
change. The quiet confidence we have when deploying new code to production is the true measure of its success.
That averted outage wasn't luck; it was design.
