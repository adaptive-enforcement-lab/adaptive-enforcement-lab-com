---
title: Actions Integration
description: >-
  Integrate GitHub Core Apps with Actions workflows.
  Token generation, org-scoped access, and cross-repository operations.
tags:
  - patterns
  - automation
  - ci-cd
  - developers
  - operators
  - github-actions
---

# GitHub Actions Integration with Core App

This guide explains how to integrate your GitHub Core App with GitHub Actions
workflows for organization-level automation.

!!! abstract "What You'll Learn"
    Generate short-lived tokens, use them with GitHub CLI and APIs, implement common workflow patterns, and handle errors gracefully.

## Prerequisites

Before integrating, ensure you have:

1. **Core App created and installed** - See [GitHub App Setup](../../../secure/github-apps/index.md)
2. **Secrets configured** - `CORE_APP_ID` and `CORE_APP_PRIVATE_KEY` stored in GitHub
3. **Required permissions** - App has permissions for your automation tasks

## What's Covered

This section walks through the complete integration lifecycle:

- [Token Generation](token-generation.md) - Generate short-lived tokens from Core App credentials
- [Using Tokens](using-tokens.md) - Integrate tokens with GitHub CLI, Git, and APIs
- [Workflow Patterns](workflow-patterns.md) - Common automation patterns
- [Token Validation](token-validation.md) - Verify token scope and permissions
- [Workflow Permissions](workflow-permissions.md) - Configure workflow-level permissions
- [Error Handling](error-handling.md) - Handle failures gracefully
- [Security Best Practices](security-best-practices.md) - Keep tokens secure
- [Troubleshooting](troubleshooting.md) - Debug common issues
- [Performance Optimization](performance-optimization.md) - Optimize for speed

## References

- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [GitHub CLI Manual](https://cli.github.com/manual/)
- [GitHub GraphQL API](https://docs.github.com/en/graphql)
- [GitHub Core App Setup](../../../secure/github-apps/index.md)
