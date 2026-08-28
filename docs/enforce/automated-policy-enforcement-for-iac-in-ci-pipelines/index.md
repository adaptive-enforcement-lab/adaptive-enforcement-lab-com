---
title: Automated Policy Enforcement for IaC in CI Pipelines
nav_title: Automated Policy
description: >-
  Use CI/CD pipeline integration to proactively check Infrastructure as Code (IaC) against security, compliance, and cost policies before deployment.
---
Embedding automated policy enforcement into a continuous integration (CI) pipeline
provides early detection of infrastructure drift and non-compliant configurations,
effectively shifting compliance validation to the left. This approach transforms
policy from a manual, after-the-fact review into a proactive, developer-centric workflow.

!!! warning "Start in Non-Blocking Mode"
    A common pitfall is enabling build failures for all policies from day one.
    This can alienate development teams by blocking legitimate work with false positives
    or low-priority issues. Always begin in an audit-only or "non-blocking" mode
    to build trust, gather baseline data, and fine-tune policies before enabling enforcement.

## Choosing an Integration Point

The first step is to determine where in the CI process the policy checks should run.
The ideal point is early enough to provide fast feedback to the developer, but
late enough to have a complete picture of the proposed infrastructure changes.
For most teams, this means running checks immediately after an `IaC plan` or
equivalent planning stage, but before any `apply` step is initiated.

Integrating at the pull request (PR) stage is the most common and effective pattern.
By triggering the policy scanner on every commit to a feature branch, feedback is
delivered directly in the PR via status checks, comments, or annotations. This keeps
the entire review cycle: code, peer feedback, and policy compliance, within a single,
familiar developer workflow.

## Phasing the Policy Rollout

A phased rollout strategy is critical for successful adoption. Rather than enabling
blocking policies all at once, a gradual approach is recommended. Initially,
policies can be run in a non-blocking or audit-only mode to gather data on
existing non-compliance. This helps in understanding the current state and tuning
the policies. Over time, as confidence in the policies grows, they can be
transitioned to produce warnings and, eventually, to fail the CI build for
critical issues.

## Structuring the Policy Codebase

Treating your policies as code means they should be version-controlled in their own
repository, separate from the infrastructure code they validate. This separation of
concerns allows the platform or security team to manage the policy lifecycle
independently from the application teams who consume them.

A typical structure includes separate directories for policy definitions and any shared
functions or libraries. A configuration file can be used to define policy sets, and the entire
codebase should be version-controlled with automation for testing and publishing new versions.

## Defining Policy Sets

Not all policies are created equal. Grouping policies into logical sets with clear
purposes helps teams understand the intent and criticality of a violation.
These sets can be categorized by their purpose, such as security, cost control,
and best practices, with each category containing related policies.

## Handling Violations and Exceptions

When a CI pipeline fails due to a policy violation, developers need a clear and
immediate path to resolution. The error message in the CI log is the most
critical piece of this user experience. It should be explicit, stating exactly
which policy was violated and which resource is non-compliant. Most importantly,
it must include clear instructions or a link to documentation on how to remediate
the issue.

No policy set is perfect, and there will always be valid reasons for exceptions.
An exception process must be defined, but it should not be a simple "ignore" flag
in the code. A robust process for handling exceptions is essential, and it should be well-documented and consistently followed.

## Communicating Policy Failures to Developers

Feedback is most effective when delivered in-context. While failing a pipeline
is a clear signal, it is not always the most user-friendly. Augmenting pipeline
failures with automated PR comments can significantly improve the developer
experience. A well-crafted bot comment can provide a summary of all violations,
link to the exact lines of IaC code that are at fault, and offer direct links
to remediation guides. This reduces the friction of context-switching from the
code review tool to the CI log viewer and back.
