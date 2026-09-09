---
title: The Five-Minute Audit
date: 2026-09-09
authors:
  - mark
categories:
  - DevOps
  - Compliance
  - CI/CD
description: >-
  Automate compliance checks in your CI pipeline to prevent dependency license violations and ensure faster, safer releases. Learn how we did it.
slug: the-five-minute-audit
---
A compliance issue could be flagged automatically just minutes after a code change,
preventing a release that might otherwise cause a significant headache. The developer
who made the change had already moved on to their next task, completely
unaware of the downstream chaos they’d nearly unleashed. But there was
no chaos. No frantic calls, no emergency rollbacks. Just a red X, a clear
error message in a Slack channel, and a link to the relevant policy. A
new version of the change, this time compliant, was on its way moments
later.

<!-- more -->

This quiet, non-event was the result of a deliberate shift in how we
handle compliance. For years, our process was painfully manual and
reactive. It involved spreadsheets, pre-release checklists, and a
heroic effort from the security team to manually audit every
production change. Deployments were a bottleneck, and compliance
was seen as a gatekeeper, a final boss battle at the end of the
development cycle. The commit history from our `auth-handler`
service tells the story of how we moved from that world to one where
compliance is just another automated check in the pipeline.

## The Breaking Point

The old way wasn't just slow; it was fragile. I remember releases being
held up for the better part of a day while a security engineer, doing a
final manual review, would notice a potential issue. It wasn't
malicious, just an oversight by a developer trying to solve a
problem quickly. But the result was an hours-long scramble to find
a solution, rebuild an artifact, and rush it through a new round
of testing. These incidents were a catalyst. We decided that compliance
couldn't be a manual, end-of-stage review anymore. It had to be an
automated, continuous part of the development workflow itself.

## Pattern: Compliance as Code

The core idea was to treat our compliance policies the same way we
treat our infrastructure: as code. If a policy could be written down,
it could be scripted. If it could be scripted, it could be run in our
CI pipeline on every single commit. This meant that instead of a
human checking a box on a form, a script would verify the state of
the codebase and fail the build if it didn't meet our standards. This
approach promised not just to catch issues earlier, but to make the
policies themselves more transparent, version-controlled, and
auditable. We started with two critical areas: the release process
itself and the identity of our software components.

## Auditing the Release Process

The first step was codifying the rules for a valid release. We
created a new, dedicated workflow file,
`.github/workflows/release-process-compliance.yml`, which contained a
series of jobs to run against any proposed release candidate. This
44-line YAML file became our automated release auditor. It didn't
care about the feature being shipped; it cared about the *how*.

The workflow was designed to enforce several key release policies.

## Auditing Component Identity

Once we had confidence in the release process, we turned our
attention to the software itself. In a large system, it’s easy
for services to become black boxes. When something goes wrong,
you need to know who owns it, where the source is, and what its
support status is. We introduced a second automated audit,
`.github/workflows/component-identity-compliance.yml`, to
enforce this.

This 51-line workflow scans for component metadata that we now require
in every service repository.

The pipeline job verifies that key fields for component identity are present and valid.

Builds fail if this information is missing, incomplete, or contains stale
information. This prevents situations where a team might try to deprecate
a component that is still a critical dependency for another service,
forcing a necessary conversation about migration planning that would have
otherwise been missed until it caused an outage.

!!! tip
    Start with one or two simple, high-impact checks. For us, we chose to
    focus on the release process and component identity. The immediate value builds
    trust and momentum. Trying to boil the ocean by implementing dozens
    of complex rules at once often leads to developer friction and a push
    to disable the very system you're trying to build.

## From Gatekeeper to Guardrail

The most significant change wasn't technical; it was cultural. With
compliance checks running in the pipeline, developers get feedback in
minutes, not days. A failed compliance check is no longer a
disciplinary issue; it's a build error, just like a failing unit
test. The compliance team, freed from manual auditing, now spends
their time consulting on new services and codifying new policies
into the automation framework. They've shifted from being
gatekeepers to being the people who build the guardrails that let
everyone else move faster, and more safely.

## The Payoff: Speed and Safety

These changes are designed to allow the `auth-handler` service to deploy more frequently and with higher confidence. The pre-release compliance review, which used to be a source
of delay, is now an automated job that completes quickly. We've taken steps to mitigate a class of production risk related to
licensing and component ownership. More importantly, we've made compliance
a shared responsibility. It's not something that happens *to*
developers; it's something the pipeline helps them get right from
the very first commit.

## Building the Feedback Loop

The key to making this work is the quality of the feedback. A
failed check that just says "Error: Compliance Violation" is
useless. We invested time in writing clear, actionable error
messages. For a failed check, the goal is to provide developers with
clear, actionable feedback, turning a failed build from a frustrating
blocker into a learning opportunity.

## What's Next?

This journey started with a single service, but the pattern is
spreading. We now have a central repository of these compliance jobs
that any team can import into their pipeline. The next frontier is
infrastructure. We're working on applying the same "compliance as
code" pattern to our Terraform and Kubernetes manifests, ensuring
our infrastructure configuration adheres to security best practices
before it ever gets applied. The goal is the same: make the right way
the easy way, and let the pipeline handle the rest.
