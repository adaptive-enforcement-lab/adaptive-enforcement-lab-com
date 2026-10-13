---
title: Managing Pre-Commit Hooks with Declarative YAML
nav_title: Declarative Pre-Commit
description: >-
  Learn how to use declarative YAML files to manage pre-commit hooks, improving consistency and maintainability in your workflows.
---
Adopting declarative YAML for managing pre-commit hooks provides a clear, version-controlled, and automated way to enforce code quality standards across projects.

!!! note
    While this guide focuses on pre-commit hooks, the principles of declarative configuration can be applied to many other workflow automation scenarios, such as CI/CD pipelines and infrastructure provisioning.

## What are Pre-Commit Hooks?

Pre-commit hooks are scripts that run automatically before a developer can commit code to a version control repository. These hooks can be used to perform a variety of tasks, such as:

*   **Linting:** Checking code for syntax errors and style violations.
*   **Formatting:** Automatically formatting code to match a consistent style.
*   **Testing:** Running unit tests to ensure that new code doesn't break existing functionality.
*   **Security scanning:** Scanning for security vulnerabilities and secrets in code.

By running these checks automatically, pre-commit hooks help to improve code quality, reduce the number of bugs, and enforce consistency across a codebase.

## Imperative vs. Declarative Hook Management

There are two main approaches to managing pre-commit hooks: imperative and declarative.

*   **Imperative:** In an imperative approach, you would typically write a series of scripts that are manually installed and managed on each developer's machine. This can be error-prone and difficult to maintain, especially in large teams.
*   **Declarative:** In a declarative approach, you define the desired state of your pre-commit hooks in a configuration file, typically in YAML format. This file can be version-controlled along with your code, ensuring that all developers are using the same set of hooks.

The following table highlights the key differences between these two approaches:

| Feature              | Imperative Approach                               | Declarative Approach                                 |
| -------------------- | ------------------------------------------------- | ---------------------------------------------------- |
| **Configuration**    | Manual, script-based                              | Centralized, YAML-based                              |
| **Version Control**  | Difficult to version control                      | Easily version-controlled with code                  |
| **Reproducibility**  | Can be inconsistent across different environments | Highly reproducible                                  |
| **Maintainability**  | Difficult to maintain and update                  | Easy to maintain and update                          |
| **Onboarding**       | Requires manual setup for new developers          | Simplified onboarding with automated setup         |

## The Declarative Approach: `.pre-commit-config.yaml`

The `pre-commit` framework is a popular tool for managing pre-commit hooks in a declarative way. It uses a YAML configuration file named `.pre-commit-config.yaml` to define the hooks that should be run.

A typical `.pre-commit-config.yaml` file looks like this:

```yaml
repos:
-   repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.3.0
    hooks:
    -   id: check-yaml
    -   id: end-of-file-fixer
    -   id: trailing-whitespace
-   repo: https://github.com/psf/black
    rev: 22.3.0
    hooks:
    -   id: black
```

In this example, we are defining two repositories of hooks: `pre-commit-hooks` and `black`. For each repository, we specify the version to use (`rev`) and the specific hooks to enable (`hooks`).

## Benefits of Declarative Hook Management

Adopting a declarative approach to pre-commit hook management offers several benefits:

*   **Improved Consistency:** By defining hooks in a version-controlled configuration file, you can ensure that all developers are using the same set of checks, leading to more consistent code quality.
*   **Simplified Auditing:** The declarative nature of the configuration file makes it easy to audit the hooks that are being used in a project.
*   **Easier Onboarding:** New developers can quickly get up and running with the required hooks by simply installing the `pre-commit` framework and running `pre-commit install`.
*   **Enhanced Maintainability:** Updating hooks is as simple as changing the version number in the configuration file, as shown in the practical example below.

## A Practical Example: Updating a Hook

The commit history for our internal "workflows" repository shows a real-world example of updating a pre-commit hook in a declarative way. The commit message "chore(deps): update pre-commit hook neon-ch/cloud-platform-sdk to v1.0.2" indicates that the `cloud-platform-sdk` hook was updated to a new version.

This update was achieved by simply changing a single line in the `.pre-commit-config.yaml` file:

```diff
-    rev: v1.0.1
+    rev: v1.0.2
```

This simple change automatically updates the pre-commit hook for all developers who pull the latest version of the code, ensuring that everyone is using the new version of the hook without any manual intervention.

## Common Pitfalls and Best Practices

When implementing declarative pre-commit hooks, it's important to be aware of the following pitfalls and best practices:

*   **Hook Execution Time:** Be mindful of the number and complexity of the hooks you enable. Too many long-running hooks can slow down the development process and lead to frustration.
*   **Hook Versioning:** Always pin your hooks to a specific version number to ensure that your builds are reproducible.
*   **Local vs. CI Environments:** Ensure that the same hooks are run in both local development environments and in your continuous integration (CI) pipeline to catch any issues early in the development process.

!!! warning
    It is crucial to periodically review and update your pre-commit hooks to ensure they are still relevant and effective. Outdated hooks can provide a false sense of security and may not catch the latest issues.

By following these best practices, you can effectively leverage declarative pre-commit hooks to improve the quality and consistency of your codebase.
