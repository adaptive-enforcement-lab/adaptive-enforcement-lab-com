---
title: Controlled Dependency Promotion Across Environments
date: 2026-10-20
authors:
  - mark
categories:
  - Engineering
  - DevOps
description: >-
  Automated commits promoting configuration policies revealed a pattern of controlled, reliable dependency management across environments.
slug: controlled-dependency-promotion-across-environments
---
The commit message was unassuming: `chore(promote): devops-policy 0.4.1 → DEV`.
It was one of hundreds that week, a tiny, automated change updating a single value
in a YAML file. Yet, that small commit represented the culmination of a long journey
to tame the chaos of managing dependencies across our different environments.

<!-- more -->

## The Problem with Manual Promotions

Before we built our automated promotion system, managing dependencies was a manual,
error-prone process. A developer would update a library, test it in their local
environment, and then create a pull request to update the dependency in the development
environment. Then, another PR for staging, and another for production. Each step was
a potential point of failure. Different versions of dependencies would end up in
different environments, leading to subtle bugs that were difficult to track down.
Rollbacks were a nightmare, often involving frantic `git revert` commands and
late-night war rooms.

## Designing for Consistency

We knew we needed a better way. Our goal was to create a system that was:

- **Reliable:** Promotions should be repeatable and predictable.
- **Auditable:** We needed a clear record of what was promoted, when, and by whom.
- **Automated:** Manual steps should be eliminated wherever possible.
- **Flexible:** The system should support different promotion cadences for different types of dependencies.

We settled on a GitOps-based approach. The `main` branch of our configuration repository would be the single source of truth for the desired state of our infrastructure. All changes, including dependency updates, would be made through pull requests to this repository.

## The `devops-policy` Chart

The `devops-policy` chart, mentioned in the commit message, is a key part of this system. It's a Helm chart that encapsulates a set of common policies for all our services. This includes things like:

-   Resource limits
-   Liveness and readiness probe configurations
-   Security context constraints
-   Standardized labels and annotations

By centralizing these policies in a single, versioned chart, we can ensure that all our services adhere to the same standards.

## The Promotion Pipeline

Our promotion pipeline is triggered whenever a new version of the `devops-policy` chart is published. Here's how it works:

1.  A developer makes a change to the `devops-policy` chart and publishes a new version (e.g., `0.4.1`).
2.  A webhook triggers a GitHub Actions workflow.
3.  The workflow automatically creates a pull request to update the `devops-policy` version in the `cd/dev/values.yaml` file in our configuration repository.
4.  The pull request is automatically merged after passing a suite of automated tests.
5.  Our GitOps controller, Argo CD, detects the change to the `main` branch and automatically applies the updated configuration to our development environment.

Promotions to staging and production follow a similar process, but with a crucial difference: they require manual approval. This gives us the flexibility to control the rollout of changes to our more sensitive environments.

!!! warning
    It's critical to have a strict versioning scheme for your dependencies. We use semantic versioning to ensure that we don't accidentally introduce breaking changes.

## The Rollback That Wasn't

One of the biggest benefits of this system is how it simplifies rollbacks. Shortly
after we implemented the automated promotion system, a new version of a critical library
was promoted to our development environment. The change passed all the automated tests,
but it introduced a subtle performance regression that wasn't caught until it was deployed.

In the old world, this would have been a major incident. We would have had to manually
revert the change, rebuild the service, and redeploy it, all while dealing with
the pressure of a production outage. With our new system, the rollback was as simple
as reverting the automated promotion commit. Our GitOps controller took care of the rest,
automatically rolling back the change in our development environment.

## Gaining Speed and Confidence

The automated promotion system has been a game-changer for us. We can now promote
dependencies to our development environment multiple times a day, with confidence
that the process is safe and repeatable. This has allowed us to catch integration
issues earlier in the development cycle and has significantly reduced the time it
takes to get new features and bug fixes to our users.

## Beyond Dependency Promotion

The pattern of using a GitOps-based approach to manage configuration is not limited
to dependency promotion. We're now using it to manage all aspects of our infrastructure,
from Kubernetes deployments to cloud resources. It has become the foundation of our
entire delivery pipeline.

## The Future is Automated

Our journey to a fully automated, GitOps-based delivery pipeline is far from over. We're constantly looking for ways to improve our system and to automate more of the manual steps in our development process.
But the unassuming commit message, `chore(promote): devops-policy 0.4.1 → DEV`, serves as a constant reminder of how far we've come.
