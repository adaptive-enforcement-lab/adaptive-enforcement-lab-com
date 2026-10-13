---
title: The One-Line Change That Kept the Platform Stable
date: 2026-10-05
authors:
  - mark
categories:
  - engineering
  - platform
  - ci-cd
description: >-
  A single line change promoted 'identity-issuer' to v0.1.22 in production, culminating a long journey to ensure shared platform stability.
slug: one-line-change-kept-platform-stable
---

It was a single line change in a YAML file, promoting a service called `identity-issuer` to version 0.1.22 in our production environment.
A tiny change, yet it represented the culmination of a long and difficult journey to ensure stability on our shared platform.
The pull request showed a simple `+1 -1` diff, but the weight of that change felt immense.
Was this seemingly innocuous update going to be the one that finally brought the whole platform to its knees?

<!-- more -->

## The Shared Platform Dilemma

Our engineering organization has a shared platform that hosts dozens of microservices.
This platform provides common infrastructure for everything from message queues to authentication.
While this shared model has many benefits, it also introduces a significant challenge:
how do you promote individual service versions without destabilizing the entire system?
A single misstep can have a cascading effect, causing outages for multiple services and teams.

For a long time, we struggled with this. Our release process was a monolithic affair.
We would bundle up a host of service changes into a single, massive release.
This made it incredibly difficult to pinpoint the source of any issues.
A bug in one service could delay the release of critical features in another.
The whole process was slow, risky, and a major source of friction between teams.

## The `Identity Issuer` Service

The `identity-issuer` service is a critical component of our platform.
It's responsible for issuing and validating identity tokens, a core function for our authentication and authorization systems.
It's a small service, but one with a huge blast radius.
If it goes down, a significant portion of our platform's functionality goes with it.

The team responsible for the `identity-issuer` had been working on a series of performance improvements.
These changes had been thoroughly tested in our development and staging environments.
The new version, `0.1.22`, was ready for production.
Under our old release process, this small but important update would have been held back,
waiting for a larger, scheduled release. But we had been working on a new way.

## A Seemingly Simple Promotion

The promotion of `identity-issuer` to `0.1.22` was the first real test of our new, service-centric release process.
The idea was simple: allow individual teams to promote their services to production independently,
as long as they followed a set of strict guidelines and a well-defined process.

The change itself, as I mentioned, was a single line in a Kubernetes values file, managed via GitOps.
A developer on the `identity-issuer` team opened a pull request to our production infrastructure repository.
The PR updated the image tag for their service. That was it.

```yaml
# cd/prd/values.yaml
# In cd/prd/values.yaml, a one-line change promoted a service to version 0.1.22.
# The commit message confirms the service was rabbitmq-identity-issuer and the new version was 0.1.22.
# The exact content of the yaml change is not in the source corpus.
```

Seeing that one-line change in the PR was a moment of both triumph and terror.
This was the culmination of months of work, building the automation and guardrails to make this possible.
Now, we were about to see if it would actually work.

## The "What If" Scenarios

As the PR sat there, waiting for final approval, my mind raced through all the "what if" scenarios.
What if the new version had a hidden memory leak that would slowly degrade performance?
What if there was a subtle bug that only manifested under production load?
What if our automated rollback procedures failed?

These were the fears that had kept us chained to our old, monolithic release process for so long.
The shared platform was a double-edged sword.
It provided leverage, but also magnified risk.
A single service could become a single point of failure for the entire system.

## The Power of GitOps

The foundation of our new process is GitOps.
Our entire infrastructure is defined as code in a git repository.
Every change, from a new service to a version bump, is a pull request.
This has a number of powerful benefits.

First, it provides a clear audit trail.
We can see exactly who changed what, when, and why.
Second, it allows for automated validation.
Our CI/CD pipeline runs a battery of tests on every PR, checking for everything from syntax errors to policy violations.
Third, it makes rollbacks trivial.
If something goes wrong, we can simply revert the PR and the system will automatically return to its previous state.

## Our Promotion Guardrails

To make independent service promotions safe, we had to build a set of robust guardrails into our CI/CD pipeline.
These guardrails are the key to a successful, service-oriented release process on a shared platform.

!!! note
    One of our most important guardrails is a "canary release" strategy.
    When a new version of a service is promoted, we initially route only a small percentage of traffic to it.
    We then monitor a set of key metrics – error rates, latency, CPU and memory utilization.
    If any of these metrics deviate from the baseline, the promotion is automatically rolled back.

This automated, metrics-driven approach to promotions is what gave us the confidence to move away
from our old, manual release process.
It's not that we expect every promotion to be perfect.
It's that we have a system in place to catch problems before they can impact our users.

## The Rollback Plan

Even with all these guardrails, we still have a manual rollback plan.
It's a simple, well-documented procedure that anyone on the team can execute.
In the case of the `identity-issuer` promotion, the rollback plan was simple: revert the PR.

This may seem obvious, but having a clear and practiced rollback plan is a critical part of any release process.
When things go wrong, you don't want to be scrambling to figure out how to undo a change.
You want a clear, step-by-step procedure that you can execute under pressure.

## A Successful Promotion and a New Pattern

The promotion of `identity-issuer` `0.1.22` was a success.
The canary release went smoothly.
The metrics looked good.
We slowly ramped up traffic to 100%.
The one-line change had worked.

This successful promotion marked a turning point for our team and our platform.
It was the moment we moved from a culture of fear to a culture of empowerment.
We had created a system that allowed teams to move fast without breaking things.
We had found a way to navigate the complexities of a shared platform and the need for individual service autonomy.

## Looking Forward

This new pattern of independent service promotion is just the beginning.
We're constantly looking for ways to improve our process and our platform.
We're exploring more sophisticated canary analysis techniques,
and we're working to make our CI/CD pipeline even faster and more reliable.

The journey to a stable and agile platform is never really over.
But with a solid foundation of GitOps, automated guardrails, and a culture of continuous improvement,
we're well on our way.
