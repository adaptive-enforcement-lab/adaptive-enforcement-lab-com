---
title: From 220 Lines of Debt to a Single CI Template
date: 2026-09-10
authors:
  - mark
categories:
  - DevOps
  - CI/CD
  - Engineering
description: >-
  A recent CI update cut 220 lines of debt to 50, standardizing our deployment
  tooling. It's the result of a year-long strategy for centralized CI/CD.
slug: from-220-lines-of-debt-to-a-single-ci-template
---
A pull request to update a service's CI pipeline landed. It deleted 220 lines
of YAML and shell script, adding only 50. The test suite passed, the
deployment succeeded, and the service hummed along as if nothing had happened.
A 75% reduction in pipeline code with zero functional changes looks like a magic
trick, but it was the quiet, deliberate outcome of a strategy we'd been
executing for over a year: standardizing our CI/CD practices by moving from
scattered, bespoke scripts to a shared, centrally managed template.

<!-- more -->

This one small change, in a single repository, was a concrete validation of
the entire approach. It revealed how much duplicated, and often divergent,
logic we had accumulated across our services, and it showed us the path to
paying down that technical debt.

## The Problem: Divergent CI Logic

For years, our approach to CI/CD was, to put it charitably, "decentralized."
When a new service was created, the path of least resistance was to copy the
`bitbucket-pipelines.yml` from a similar, existing service. This worked, mostly.
But every copy was a fork. Over time, each service's pipeline would accrete its
own special fixes, environment-specific logic, and one-off helper scripts.

A security patch applied to one service wouldn't get propagated to the others.
An improvement to the deployment process in one pipeline would remain isolated
there. We had dozens of slightly different definitions of "production," "staging,"
and "dev." A simple task like validating ingress paths was handled by a
custom-built container in some repos, inline bash in others, and not at all in
a few we discovered later. The cognitive overhead for any engineer moving
between services was enormous, and the risk of a simple copy-paste error
causing an outage was very real.

## Initial Attempts: The Copy-Paste "Template"

Our first attempt at standardization was to create a "golden" pipeline file in a
wiki and ask everyone to use it. This was, in retrospect, naive. It was still a
copy-paste model, just with a single, blessed source. Within weeks, the
divergence began anew. The "golden" template was a snapshot in time, and as our
tooling and infrastructure evolved, it quickly fell out of date.

Project teams couldn't wait for a central authority to update the official
template. They had deadlines. So they’d "fix" the template inline, right in
their service repo. And just like that, we were right back where we started:
dozens of forks, each with its own unique set of features and fixes. We hadn't
created a standard; we had created a very popular starting point for custom
solutions.

## A Centralized Solution: The Policy Platform

The turning point was the realization that the pipeline configuration itself
needed to be a managed artifact, just like our container images or software
libraries. We needed to be able to version it, test it, and distribute it. We
needed to stop shipping YAML files and start shipping a CI/CD toolkit.

This led to the creation of what we call the "Policy Platform." It's a simple
concept: a dedicated container image, published to our internal registry, that
contains all the command-line tools, scripts, and configuration necessary to
test, validate, and deploy a service. Instead of each service's pipeline having
to know *how* to do these things, it only needs to know how to invoke the Policy
Platform.

## What's in a Template?

The new, standardized pipeline template that consumes the Policy Platform is
shockingly simple. Its main responsibilities are to check out the code, pull and
execute the Policy Platform container, and pass a few service-specific
parameters to the container. All the complex logic that used to be embedded in hundreds of lines
of YAML is now encapsulated within the platform's tooling. For example,
environment detection, which involves figuring out whether the pipeline is
running against a feature branch, staging, or production, used to be a
convoluted block of `if/elif/else` bash scripting. Now, it's a single command
provided by the platform: `detect-environment`. The pipeline just executes that
command and uses its output.

!!! warning

    A centrally managed template is a powerful tool, but it also introduces a new
    dependency. A breaking change in the Policy Platform could, in theory, break
    every single service's deployment pipeline at once. Rigorous testing of the
    platform itself, including running it against a representative sample of
    service pipelines before release, is absolutely non-negotiable.

## The Big Migration: A Case Study

The commit that inspired this post (SHA `0eb07f99`) is a perfect example of the
migration process. The repository, `playground-devops`, was using a pipeline
template from January 2025 (version 1.0.2). It was a relic, full of the exact
patterns we wanted to eliminate.

The old file contained 220 lines of code dedicated to tasks that were now
handled by the Policy Platform. It had its own inline bash for environment
detection and invoked a long-retired `ingress-path-validation` container. The
update replaced all of that with a 50-line file that was byte-identical to the
new `policy-platform` template (version 1.4.0).

## From Inline Bash to a Single Command

The most significant change was replacing sprawling, custom logic with clean,
single-purpose commands.

Where the old pipeline had a script block like this:

```bash
- |
  if [ "$BITBUCKET_BRANCH" == "main" ]; then
    export DEPLOY_ENV="production"
  elif [[ "$BITBUCKET_BRANCH" == feature/* ]]; then
    export DEPLOY_ENV="dev"
  else
    export DEPLOY_ENV="staging"
  fi
```

The new one simply has:

```yaml
- DEPLOY_ENV=$(detect-environment)
```

Similarly, a whole stanza dedicated to pulling and running a separate container
for ingress validation was replaced by a single line in the platform's main
script step: `policy-platform validate ingress-paths`

This abstraction is the key. The service pipeline no longer needs to care *how*
ingress paths are validated, only *that* they are. When we need to update the
validation logic, we do it once, in the Policy Platform. We release a new
version of the image, and every service that uses the template automatically
inherits the change on its next run.

## Measuring Success: Beyond Line Counts

The 75% reduction in code is a fantastic headline number, but the real benefits
run deeper. Onboarding a new service is now trivial. We no longer have long
debates about how to structure the pipeline; there is one right way. The
developer experience is vastly improved. Engineers can look at any service's
pipeline file and immediately understand what's happening, because they all look
the same.

This consistency has also made us faster and safer. When a critical
vulnerability is discovered, we no longer have to scramble to
audit dozens of unique pipelines to see which ones are using a vulnerable
dependency. We update the base image of the Policy Platform, and we have high
confidence that the fix is rolled out everywhere.

## The Governance Payoff

An unexpected benefit of this approach has been in governance and compliance.
Because all deployments now go through the Policy Platform, we have a single,
auditable chokepoint. We can enforce rules, such as requiring a valid ticket
number in the commit message for production deployments, in one place.

Before, this logic was either not enforced or was enforced inconsistently by yet
another block of custom script in each pipeline. Now, it's a simple,
non-negotiable check inside the platform. If the check fails, the deployment
stops. This has made our audit and compliance story dramatically simpler and
more robust.

## What's Next?

We've migrated the vast majority of our core services to this new model, but the
work isn't done. We're continually looking for common patterns that can be
extracted from the remaining bespoke pipelines and absorbed into the Policy
Platform. The goal is not to eliminate all flexibility, but to ensure that
custom logic is the exception, not the rule.

The journey from hundreds of lines of fragile, duplicated code to a single,
versioned template has been a long one. But every time I see a pull request
that deletes more code than it adds, I know it was worth it. It’s a quiet
victory for simplicity and sanity in a complex world.
