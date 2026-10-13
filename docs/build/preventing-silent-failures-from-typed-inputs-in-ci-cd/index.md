---
title: Preventing Silent Failures from Typed Inputs in CI/CD
nav_title: Typed Inputs
description: >-
  Robust CI/CD pipelines depend on correctly handling typed inputs to prevent silent failures during component publishing. This guide outlines how to diagnose and fix these subtle, damaging bugs.
---

Implementing robust CI/CD pipelines requires careful handling of typed inputs to avoid silent failures in component publishing. Even with declared types, variations in how workflow contexts handle data can lead to logic errors that are invisible until they cause downstream application failures.

!!! warning "The Danger of Silent, Green Failures"
    A skipped CI/CD job often reports as "green" or "successful." This creates a false
    sense of security while a critical component—like a Helm chart or a software library—
    is not being published. The failure only surfaces later, during a deployment or
    integration that depends on the missing artifact.

## The Anatomy of a Silent Failure

A common failure pattern occurs when a CI/CD workflow incorrectly evaluates a boolean
input parameter. A recent incident in a component pipeline for a critical
infrastructure service demonstrated this vulnerability. A workflow designed to
publish a Helm chart to a registry was silently skipping the publish step,
despite being triggered for a release.

The job was "green," but the chart was never pushed. The issue was only discovered when a downstream environment,
pinned to the new chart version, failed to deploy because the artifact did not exist in the registry. The root cause was a subtle type mismatch in a conditional check within the pipeline's workflow definition.

## Type Mismatches in Workflow Logic

The faulty workflow declared a boolean input for triggering a release. However, the conditional logic for the publishing job compared this boolean input against a string literal.

- **Input Declaration:** The workflow input `is_release` was defined with `type: boolean`.
- **Faulty Logic:** The job's conditional was `if: inputs.is_release == 'true'`.

Because `inputs.is_release` was a true boolean (not a string), the comparison `true == 'true'` always evaluated to false, and the job was permanently skipped.
The error was difficult to spot because other parts of the workflow correctly handled the boolean, making the faulty line seem innocuous during code review.

## Correctly Evaluating Input Types

The context in which an input is evaluated determines how it should be handled. In GitHub Actions, for example, the `inputs` context and the `github.event.inputs` context behave differently. Understanding these nuances is key to writing reliable pipeline logic.

The following table clarifies the correct syntax for evaluating a boolean input named `X` in various contexts:

| Context or Location         | Correct Syntax                      | Explanation                                                              |
| --------------------------- | ----------------------------------- | ------------------------------------------------------------------------ |
| `if:` condition on a job/step | `inputs.X == true`                  | The `inputs` context respects the declared `type: boolean`.              |
| `if:` condition on a job/step | `github.event.inputs.X == 'true'`   | The `github.event.inputs` context casts all inputs to strings.           |
| `run:` block (shell script) | `[ "${{ inputs.X }}" == "true" ]`   | Inside a script, the input is rendered as text before the shell executes. |

Adopting a consistent and correct approach based on the context is the most effective way to prevent these type-related errors. Relying on the typed `inputs` context is generally the most robust method when available.

## The Rippling Effect of Silent Failures

A silently skipped job is not an isolated event; it creates cascading problems. In the case of the missing Helm chart, the immediate impact was a failed deployment.
However, the full consequences included:

-   **Delayed Releases:** A feature or bug fix believed to be released was, in fact, never deployed.
-   **Wasted Engineering Time:** Teams spent hours debugging the downstream deployment failures instead of the true source in the CI pipeline.
-   **Eroded Trust in Automation:** When "green" builds don't produce reliable outcomes, developers lose confidence in the CI/CD system and may resort to manual checks, defeating the purpose of automation.

## Proactive Measures for Robust Pipelines

Preventing these silent failures requires a multi-layered approach that combines best practices in workflow authorship and process.

1.  **Explicit Type Handling:** Be deliberate about type comparisons. When in doubt, add steps to your workflow to echo and inspect the type and value of inputs at runtime to ensure your assumptions are correct.
2.  **Mandatory End-to-End Testing:** A deployment pipeline should not just build and push; it should trigger a subsequent action, like a deployment to a staging environment or a health check. A successful publish should be confirmed by a subsequent, dependent job's ability to pull and use the artifact.
3.  **Thorough Peer Review:** Code reviews for CI/CD workflows must be as rigorous as for application code. Reviewers should specifically question conditional logic and input handling, paying close attention to type-sensitive comparisons.
4.  **In-Job Assertions:** Rather than relying solely on a job's implicit success, add explicit assertions within the job script. For instance, after a publish step, a script can use the registry's API to confirm the new artifact version exists and is accessible.
If the check fails, the job should be explicitly failed.

By embedding these practices into the development lifecycle, teams can build more resilient CI/CD pipelines that are less susceptible to silent, type-related failures.
