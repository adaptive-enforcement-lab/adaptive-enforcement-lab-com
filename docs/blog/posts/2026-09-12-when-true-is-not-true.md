---
title: When 'true' Is Not True
date: 2026-09-12
authors:
  - mark
categories:
  - ci-cd
  - automation
  - engineering
description: >-
  For some time, every build job for our packaged components was green. Yet, our
  registry was only ever seeing pre-release builds, never a final
  release.
slug: when-true-is-not-true
---
For some time, every build job for our packaged components was green. Every test
passed, every check was marked successful. Yet, our registry was only
ever seeing pre-release builds, never a final release. The promotion job, the
final gatekeeper that should have been tagging and publishing the official
artifacts, was silently failing to do its one job, all while reporting complete
success. The problem wasn't in a complex script or a failing dependency; it was
hiding in a single, seemingly innocent line of our workflow configuration.

<!-- more -->

This wasn't a catastrophic failure that brought systems down, but a subtle
corrosion of process. It was a green light that lied, and it exposed a
fundamental misunderstanding in our automation pipeline: how we handle even the
simplest of data types as they flow between jobs. The bug was a mismatch between
a boolean `true` and the string `"true"`, a tiny distinction with significant
consequences for our release automation.

## The Green Light That Lied

Our CI/CD platform is the backbone of our deployment strategy. A series of
automated jobs, triggered by commits and pull requests, builds, tests, and
packages our software. For our containerized services, this culminates in
publishing a component package to a shared registry. The system uses a specific
flag, let's call it `is_release`, to distinguish between a regular development
build and an actual release candidate.

The workflow logs told a story of perfect execution. We could see the release
automation tool correctly detect a new release was needed. We could see it
trigger the component packaging job, passing along the instruction to create a
release. We could see that packaging job run to completion, exit with a zero
status code, and report a green checkmark. But when we went to the registry, the
tagged release artifact wasn't there. Instead, we'd find another development
build, indistinguishable from any other pre-release snapshot.

The failure was silent because, from the runner's perspective, nothing had gone
wrong. No command had failed. No script had thrown an error. The job simply
evaluated a condition, found it to be false, and proceeded down the "not a
release" path. Because that path also ended in a successful exit code, the
platform reported a victory.

## A Tale of Two Truths

After hours of tracing the flow of variables through logs, the culprit came into
view. It was a conditional check in the workflow definition that determined
whether to publish the package as a full release. The logic was simple:
`if: inputs.is_release == true`.

The problem was that `inputs.is_release` was not, in fact, a boolean.

Deeper in the system, our release automation tool determined whether a release
was warranted. It would then call our packaging workflow and pass along its
conclusion. To do this, it rendered the value into a command-line argument for a
downstream tool:
`-f helm_is_release="${{ needs.release-please.outputs.helm_release_created == 'true' }}"`.
This process, a common pattern in CI/CD orchestration, turns everything into a
string. The boolean `true` from the upstream job became the string `"true"` by
the time it arrived at our packaging workflow.

So, the check `inputs.is_release == true` was, in reality, evaluating
`"true" == true`. In the type system used by our CI/CD platform's expression
handler, this comparison is always, unequivocally, false. A string, even one
that contains the letters t-r-u-e, is not the same as a boolean primitive.

## Digging into the Workflow Definition

The specific workflow file was clear. An input was defined to control the
release state. It was explicitly declared as `type: string`, with a description
indicating it controls whether it's a release build, and a default of `"false"`.

The point of failure was the one place this convention was violated: the
comparison. The condition for publishing the release package incorrectly
compared `inputs.is_release` directly to the boolean `true`
(`if: inputs.is_release == true`).

The fix was deceptively simple: add quotes. By changing the comparison to check
if `inputs.is_release == 'true'` (a string literal), the code correctly aligned
with the actual data type.

By changing the comparison to look for the string literal `'true'`, we aligned
the code with the reality of the data being passed to it. The decision was not
to change the data's type, but to fix the broken assumption in the code that
consumed it.

## The Ripple Effect of Implicit Types

This incident highlights a pervasive risk in CI/CD pipelines. They are, by
nature, loosely coupled systems, often held together by strings. Variables,
parameters, and outputs are marshaled and unmarshaled between different
contexts: YAML parsers, shell environments, scripting language runtimes. Each of
these contexts has its own rules for what "true" means. YAML might convert an
unquoted `true` to a boolean, but a shell script receiving it as an environment
variable will see the string `"true"`.

When we write automation, we create implicit contracts between these different
parts of the system. The upstream release job promised to provide a value
indicating a release. The downstream packaging job promised to act on it. The
bug arose because the contract was underspecified, leaving the interpretation of
the value ambiguous. A system that relies on implicit type coercion is a brittle
one, prone to exactly this kind of silent, perplexing failure.

## The Fix: Aligning the Code with Reality

The most important part of the fix was deciding what *not* to change. It would
have been possible to force the upstream job to produce a "real" boolean. It
might have even been possible to change the input `type` to `boolean`.

However, that would have made this one input different from every other one in
the workflow. It would have been a special case, an exception to the rule that
"all inputs are strings." Special cases are where complexity and future bugs
hide. The more uniform and predictable the system is, the easier it is to
reason about.

The true root cause was the mismatch between the declared type (`string`) and
the way it was used (`== true`). The most direct and correct fix was to make the
usage match the declaration. By changing the comparison to `== 'true'`, we
acknowledged the reality that this variable is, and always was, a string.

## A Pocket Guide to Type Checks in CI

This investigation led us to formalize a small set of patterns for handling
these kinds of checks. It's easy to get it wrong, because the "right" syntax
depends entirely on the context.

!!! tip "A Reference for CI/CD Type Comparisons"
    For our specific CI/CD platform, we now adhere to the following guide:

    -   Use `inputs.VAR == true` only when the input is explicitly declared with
        `type: boolean`.
    -   Use `inputs.VAR == 'true'` when the input is declared as `type: string`.
    -   Inside a `run` block (a shell script), use `[ "${{ inputs.VAR }}" == "true" ]`.
        The workflow expression `${{ ... }}` is rendered as text first, so the shell
        sees `[ "true" == "true" ]` and evaluates it correctly.

These simple rules ensure that we're always comparing apples to apples, removing
ambiguity and the potential for silent failures.

## Instituting Audits and Assertions

Fixing the bug was the first step. Preventing its recurrence was the next.
Inspired by this incident, we initiated a broader review of our release
processes. One of the key outcomes was the creation of a "release process
compliance audit" workflow.

This is a new, automated process that runs periodically. It doesn't build or
release anything itself. Instead, it inspects our registries and release
manifests, comparing them against the commit history. Its job is to ask
questions like: "A release was declared five days ago. Is there a corresponding
release artifact in the production registry?" or "This component has had 50
commits since its last tagged release. Is that expected?"

This audit acts as a safety net. Had it been in place, it would have flagged the
missing Helm chart releases within a day, turning a weeks-long silent failure
into a quickly resolved, explicit alert.

## The Broader Pattern: Contracts Between Jobs

Ultimately, this was a lesson in the importance of treating CI/CD pipelines as
distributed systems with API contracts. Each job that passes an output to
another is defining an API. Every variable is part of the payload. When those
contracts are implicit, relying on convention and the ambient behavior of the
platform, they are brittle.

The solution is to make those contracts explicit. By strictly defining the types
of data that flow between jobs (`type: string`) and rigorously enforcing how
that data is handled at the boundaries (the `if:` conditions), we make the
system more robust. The goal is to eliminate ambiguity wherever possible, so
that the only way a job can succeed is by doing exactly what it was intended to
do. A green checkmark must be an indicator of correctness, not just of
completion.
