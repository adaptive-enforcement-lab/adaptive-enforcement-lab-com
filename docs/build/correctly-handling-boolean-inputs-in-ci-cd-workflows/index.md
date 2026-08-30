---
title: Correctly Handling Boolean Inputs in CI/CD Workflows
nav_title: Boolean Inputs
description: >-
  Explicitly typed boolean inputs in CI/CD workflows must be handled as booleans, not strings, to prevent silent deployment failures and ensure consistent release processes.
---
Correctly handling boolean type inputs in CI/CD workflows prevents silent deployment
failures and ensures consistent release processes. A common mistake is to treat a
boolean input as a string, leading to logic that always evaluates to false and jobs
that are skipped without error, masking a problem until it surfaces as a visible failure
in a downstream environment.

!!!warning "The Danger of Inconsistent Comparisons"
    Mixing comparison styles for the same input within a single workflow file is a
    significant risk. This often leads to situations where a condition evaluates
    correctly in one part of the file but fails silently in another, creating subtle
    bugs that are difficult to trace.

## The Anatomy of a Silent Failure

A silent failure occurs when a CI/CD job is skipped, but the overall workflow reports
success. This can happen when a conditional check is based on a boolean input that is
incorrectly evaluated. For instance, a job designed to publish a new version of a
component might be skipped because the CI/CD system does not recognize the boolean
`true` input as a trigger. The workflow completes with a green checkmark, but the new
version is never published. This discrepancy only becomes apparent later, when a
downstream system that depends on the new version fails, or when an environment is
found to be running a stale version of the component. This creates a gap between the
intended state (a new version is released) and the actual state (the old version
remains), leading to confusion and delays.

## Root Cause: Type Mismatches in Workflow Inputs

The root of this problem lies in a type mismatch. When a CI/CD system's workflow
declares an input with `type: boolean`, the value passed to that input is a true
boolean, not a string. However, it is a common pattern to compare this input to the
string `'true'`. This comparison will always fail, because a boolean `true` is not
equal to the string `'true'`. The consequence is that any logic gated by this
comparison will never execute. This is a subtle but critical distinction that is often
overlooked, especially in complex workflows with many inputs and conditions.

## The Three Contexts of Input Evaluation

The correct way to evaluate a boolean input depends on the context in which it is being
used. There are three common contexts for evaluating inputs in CI/CD workflows, and each
requires a different approach:

| Context | Example | Explanation |
|---|---|---|
| Direct expression | `inputs.my_boolean == true` | Here, the input is treated as its declared type: a boolean. This is the most direct and least error-prone method when the input is known to be a boolean. |
| Event context | `github.event.inputs.my_boolean == 'true'` | In this context, all inputs are treated as strings. Therefore, the comparison must be against the string `'true'`. |
| `run` block | `[ "${{ inputs.my_boolean }}" == "true" ]` | Inside a `run` block, inputs are rendered as text before the script is executed. The shell then performs the comparison, which should be a string comparison. |

Understanding these contexts and using the correct comparison method for each is crucial
for writing robust and reliable CI/CD workflows.

## A Tale of Two Comparisons

A real-world example from a production system illustrates this problem perfectly. A
single workflow file contained two different comparisons for the same boolean input,
`helm_is_release`. In one part of the file, the input was correctly compared as a
boolean: `inputs.helm_is_release == true`. In another part of the file, it was
incorrectly compared as a string: `inputs.helm_is_release == 'true'`. The latter
comparison always failed, causing the chart publication job to be skipped silently. The
error was only discovered when a new version of a component that was tagged and released
was never pushed to the component registry, causing a deployment failure in a downstream
environment.

## How to Standardize Boolean Handling

To prevent these issues, it is essential to standardize the handling of boolean inputs
in CI/CD workflows. The following practices are recommended:

*   **Always declare boolean inputs with `type: boolean`**. This makes the intent clear
    and allows the CI/CD system to perform type checking.
*   **Use the correct comparison method for the context**. Refer to the table above to
    determine the correct method for each situation.
*   **Avoid mixed comparison styles**. Inconsistent comparisons for the same input
    within a single file or across related workflows are a major source of errors.
*   **Audit existing workflows**. Periodically review existing workflows to identify and
    correct any instances of incorrect boolean handling.

## Auditing Your Workflows

To find these silent time bombs in your own codebase, search for patterns where a
boolean input is compared to a string. For example, you could search for the string
`== 'true'` in your workflow files and then check the declaration of the input being
compared. If the input is declared as a boolean, the comparison is incorrect and should
be changed. Automated linting tools can also be configured to flag these issues,
providing an extra layer of protection against this common pitfall.
