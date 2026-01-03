---
title: Fork Workflow Security Patterns
description: >-
  Two-stage fork CI, approval gates, and trigger security decision trees
---

    branches: [main]

permissions:
  contents: read

jobs:
  security-scan:
    runs-on: ubuntu-latest
    if: github.event.pull_request.head.repo.fork == true
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Detect workflow changes
        run: |
          if git diff --name-only origin/main... | grep -q '^\.github/workflows/'; then
            echo "::warning::This PR modifies workflows"
            exit 1
          fi

      - run: npm audit --production

```

## `workflow_call` Security

Reusable workflows inherit the caller's security context, secrets, and permissions. Always validate inputs.

### Secure Reusable Workflow Pattern

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy_key:
        required: true

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Validate inputs
        run: |
          case "${{ inputs.environment }}" in
            dev|staging|production) ;;
            *) echo "::error::Invalid environment"; exit 1 ;;
          esac

      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - run: ./scripts/deploy.sh "${{ inputs.environment }}"
        env:
          DEPLOY_KEY: ${{ secrets.deploy_key }}
```

Caller workflow:

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml@b4ffde65f46336ab88eb53be808477a3936bae11
    with:
      environment: production
    secrets:
      deploy_key: ${{ secrets.DEPLOY_KEY }}
```

Pin reusable workflows to SHA. Validate all inputs. Avoid `secrets: inherit`.

## Event Payload Validation

Event payloads contain user-controlled data. Inject into shell without validation and attackers can execute arbitrary commands.

### Dangerous: Direct Payload Injection

```yaml
# DO NOT USE - SCRIPT INJECTION VULNERABILITY
name: Vulnerable Comment Handler
on:
  issue_comment:
    types: [created]

jobs:
  process:
    runs-on: ubuntu-latest
    steps:
      # DANGER: User-controlled comment body injected into shell
      - run: echo "Comment: ${{ github.event.comment.body }}"

      # DANGER: Attacker can inject commands via issue title
      - run: ./process.sh "${{ github.event.issue.title }}"
```

Attacker creates issue with malicious title. Workflow executes injected commands. Token exfiltrated to attacker server.

### Safe: Environment Variable Injection

```yaml
name: Safe Comment Handler
on:
  issue_comment:
    types: [created]

permissions:
  contents: read
  issues: write

jobs:
  process:
    runs-on: ubuntu-latest
    steps:
      - name: Process comment
        env:
          COMMENT_BODY: ${{ github.event.comment.body }}
          ISSUE_TITLE: ${{ github.event.issue.title }}
        run: |
          echo "Comment: $COMMENT_BODY"
          ./process.sh "$ISSUE_TITLE"
```

Passing payloads via environment variables prevents shell injection.

### Payload Validation Checklist

| Payload Field | Trusted? | Validation Required |
| ------------- | -------- | ------------------- |
| `github.event.comment.body` | No | Sanitize or pass via env var |
| `github.event.issue.title` | No | Sanitize or pass via env var |
| `github.event.pull_request.title` | No | Sanitize or pass via env var |
| `github.event.pull_request.body` | No | Sanitize or pass via env var |
| `github.event.pull_request.head.ref` | No | Validate branch name format |
| `github.event.inputs.*` | Partially | Validate against schema |
| `github.actor` | No | Verify against allowlist |
| `github.ref` | Yes | Can trust (GitHub-controlled) |
| `github.sha` | Yes | Can trust (GitHub-controlled) |

## Security Best Practices

1. **Default to `pull_request` for fork CI**: Use `pull_request` trigger for testing external contributions
2. **Require approval for `pull_request_target`**: Never deploy fork code without manual approval via environment protection
3. **Validate event payloads**: Pass user-controlled data via environment variables
4. **Pin reusable workflows to SHA**: Never use branch references in production
5. **Monitor fork PR activity**: Alert on workflow modifications from forks

## Troubleshooting

| Issue | Cause | Solution |
| ----- | ----- | -------- |
| Fork PRs cannot post comments | Read-only GITHUB_TOKEN | Use two-stage pattern with `workflow_run` |
| Secrets not available in fork PR | `pull_request` blocks secret access | Expected. Use OIDC or approval gate if needed |
| `pull_request_target` exposes secrets | Checked out fork code in base context | Never checkout fork code without approval gate |

## Quick Reference

### Trigger Security Decision Tree

1. **Testing fork contributions?** → Use `pull_request`
2. **Commenting on fork PRs?** → Use `workflow_run` or `pull_request_target` (no checkout)
3. **Deploying fork code?** → Use `pull_request_target` + approval gate
4. **Calling reusable workflows?** → Pin to SHA, validate inputs
5. **Processing event payloads?** → Pass via environment variables

### Common Trigger Patterns

| Use Case | Trigger | Checkout | Secrets | Approval |
| -------- | ------- | -------- | ------- | -------- |
| Test fork PR | `pull_request` | Fork HEAD | No | No |
| Comment on PR | `workflow_run` | No | No | No |
| Deploy fork PR | `pull_request_target` | After gate | OIDC | Required |
| Label PR | `pull_request_target` | No | No | No |
| Call reusable workflow | `workflow_call` | Depends | Explicit | Depends |

## Related Pages

- [Environment Protection Patterns](./environments.md) - Approval gates and deployment controls
- [Reusable Workflow Security](./reusable.md) - Secure workflow composition patterns
- [Token Permissions](../token-permissions/index.md) - GITHUB_TOKEN scoping
- [Secret Management](../secrets/index.md) - Secret exposure prevention
- [Runner Security](../runners/index.md) - Self-hosted runner fork isolation
