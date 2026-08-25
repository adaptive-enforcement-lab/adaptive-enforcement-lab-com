---
title: The CI Job That Replaced Our Release Committee
date: 2026-08-23
authors:
  - mark
categories:
  - DevOps
  - Compliance
  - CI/CD
description: >-
  The Tuesday 10 AM release-review meeting was gone. In its place was a single, green checkmark in a pull request: `release-process-compliance: success`.
slug: ci-job-replaced-release-committee
---

The Tuesday 10 AM release-review meeting was gone. In its place was a single, green checkmark in a pull request: `release-process-compliance: success`.
No more checklists in a wiki, no more cross-referencing tickets, no more asking, "Did someone remember to update the changelog?" That single, automated check confirmed it all.

<!-- more -->

This shift didn't happen overnight. It was a direct response to years of release-day anxiety and one particularly close call that forced us to rethink our entire approach to deployment integrity.

## The Tuesday Morning Dread

For years, our release process was a manual, high-stress ceremony. It revolved around a recurring calendar invite that everyone with a stake in production stability grew to dread. The meeting was a tedious, point-by-point review of a dozen-item checklist.

The product manager would confirm the feature set. A senior engineer would attest that code reviews were complete. Someone from ops would verify the infrastructure readiness. It
was a process based entirely on human attestation and trust. We were essentially asking a room full of busy people to *promise* they had done their due diligence.
The goal was to distribute responsibility so widely that, in theory, no single person could be at fault if something went wrong.
In practice, it just meant every release felt like a group of us holding our breath together.

The process was slow, prone to human error, and created a culture of suspicion rather than collaboration. Audits were a nightmare of archaeology, digging through weeks of chat logs and ticket comments to produce "evidence" that we had followed our own rules.

## A Near Miss Sparks a Change

The catalyst for change was the release that almost wasn't. A critical security patch for a core dependency was available, but it was missed during the manual dependency scan.
The `package.json` was updated, but the lockfile wasn't properly regenerated, leading to a subtle inconsistency that our manual checks didn't catch.

Our automated test suite passed, the manual QA looked good, and every item on the pre-flight checklist was ticked. We were minutes from deploying a service with a known vulnerability. The mistake was only caught by chance, when an engineer running a local build noticed a package version mismatch.

It was a stark reminder: a process that relies on people remembering to do the right thing is a process that is guaranteed to fail.
We had the tools to automate dependency updates; we'd been using bots for that for months, but we hadn't automated the *verification* that the process was working correctly.
We decided right then to stop policing people and start policing the process itself.

## Our First Check: A Simple Assertion

We didn't try to boil the ocean. Our first step, embodied in a commit simply titled `add release process compliance audit`, was to build one automated check. We started with the most painful and error-prone part of our manual process: release notes.

Our rule was simple: every release must have an updated `CHANGELOG.md`. It was a rule we broke constantly.

So, we wrote a simple script that ran in our CI pipeline. It checked two things:

1.  Does the pull request title follow the Conventional Commits specification?
2.  If so, does the `CHANGELOG.md` file contain the new version number?

It was a tiny piece of automation, just a few lines in a new workflow file.
But the first time a pull request was automatically blocked because a developer forgot to update the changelog, we knew we were onto something.
It wasn't a manager nagging them in a meeting; it was an impartial, automated gate. The feedback was immediate, direct, and unemotional.

## From Script to Policy-as-Code

That small success gave us momentum. We saw that we could translate our wiki-based checklist into executable policy. The initial script grew into a comprehensive `release-process-compliance.yml` workflow. This wasn't just a linter; it was an auditor, codified and automated.

We held a series of workshops where we took every line item from our old manual checklist and asked, "How can the CI pipeline verify this for us?"

-   "Code must be reviewed." → The pipeline now checks the platform's API to ensure the pull request has at least one approved review from a code owner.
-   "All tests must pass." → The compliance job became a meta-check, failing the release if any other required CI job (unit tests, integration tests, static analysis) had failed.
-   "Artifacts must be signed." → The job inspects the build output to ensure a valid signature is attached to every binary before it can be published.

Each rule became a step in our YAML file. The 44 lines of that initial commit laid the foundation for a system where compliance wasn't a separate activity but an intrinsic property of the pipeline.

## Codifying Component Identity

Soon after, we expanded this concept with another check: `component-identity-compliance.yml`.
As our architecture grew more complex, ensuring every deployable service, library, and function had a clear, traceable identity became critical.

This new workflow enforced another set of rules:

-   Every component must have a `component-info.json` file.
-   This file must contain a valid semantic version number.
-   It must declare a clear owner team.
-   It must list the software bill-of-materials (SBOM) for its dependencies.

This solved a huge headache for our security and platform teams. When a new vulnerability like Log4j was announced, the question "What's affected?" could be answered in minutes with a script, not in days with a company-wide scramble. We had an automated, always-current inventory
of our entire software landscape.

!!! note
    A key lesson was to make the compliance checks non-blocking at first. We ran them in a "warn" mode for a few sprints, which allowed us to find edge cases and fix components that didn't meet the new standard without grinding all development to a halt.

## The Anatomy of an Audit Job

For us, this meant creating dedicated GitHub Actions workflows that acted as our compliance officers. A typical check looks something like this, in principle:

<!-- The example workflow for Release Process Compliance should be moved to a relevant guide (e.g., docs/build/release-compliance.md) and linked from a "## Related" section. -->

The actual implementation uses more robust actions, but the principle is the same. The workflow runs on every PR targeting our main branch, effectively making compliance a mandatory step for any code to even be considered for release.

## The Green Checkmark Is the Audit Trail

The most profound change was in our relationship with auditors.
Our old process involved a frantic, backward-looking search for evidence.
We'd pull up meeting notes, ticket histories, and email threads to prove we'd followed our own policies.

Now, the conversation is different. We don't show them a wiki page; we show them the `release-process-compliance.yml` file. The policy is the code.

The evidence is no longer a collection of screenshots and links. It's the log output of the CI job itself.
Every green checkmark on a merged pull request is an immutable, timestamped record that every single compliance rule was met.
The audit trail is generated automatically as a byproduct of the development process itself.
We shifted the conversation from "Prove you followed the process" to "Prove the process is enforced."

## More Than Just Compliance: Developer Confidence

We started this journey to satisfy auditors and prevent production accidents.
The unexpected benefit was a massive improvement in developer experience. The automated `release-please` bots could now cut new versions and create release pull requests, knowing that
the compliance jobs would serve as the ultimate backstop.

Releases became non-events. They were just another merge. The fear was gone.
The pipeline was trusted because its rules were explicit, visible, and absolute.
Developers could move faster and with more autonomy because the guardrails were built-in, not bolted on.
The system gave them the freedom to focus on building features, secure in the knowledge that they couldn't accidentally violate a critical release policy.

The end of the Tuesday Morning Dread wasn't just the end of a meeting. It was the beginning of a new way of working, one built on automated trust and verifiable compliance.
