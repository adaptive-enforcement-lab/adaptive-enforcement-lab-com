---
title: Caller Validation and Workflow Pinning
description: >-
  Validating workflow callers and pinning reusable workflows to SHA references
---

        type: choice
        options:
          - dev
          - staging
          - production
        description: 'Target deployment environment'
      version:
        required: true
        type: string
        description: 'Deployment version (semantic version format)'
    secrets:
      wif_provider:
        required: true
        description: 'GCP Workload Identity Federation provider'
      wif_service_account:
        required: true
        description: 'GCP service account for deployment'
      slack_webhook:
        required: false
        description: 'Slack webhook for deployment notifications'

permissions:
  contents: read
  id-token: write

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Validate caller repository
        run: |
          ALLOWED_REPOS=(
            "org/service-frontend"
            "org/service-backend"
            "org/service-api"
          )

          CALLER_REPO="${{ github.repository }}"

          for repo in "${ALLOWED_REPOS[@]}"; do
            if [[ "$CALLER_REPO" == "$repo" ]]; then
              echo "Authorized caller: $CALLER_REPO"
              exit 0
            fi
          done

          echo "::error::Unauthorized caller: $CALLER_REPO"
          echo "::error::Allowed repositories: ${ALLOWED_REPOS[*]}"
          exit 1

      - name: Validate version format
        run: |
          VERSION="${{ inputs.version }}"

          if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9\.]+)?$ ]]; then
            echo "::error::Invalid version format: $VERSION"
            echo "::error::Expected format: vX.Y.Z or vX.Y.Z-prerelease"
            exit 1
          fi

          echo "Valid version: $VERSION"

  deploy:
    runs-on: ubuntu-latest
    needs: validate
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.wif_provider }}
          service_account: ${{ secrets.wif_service_account }}

      - name: Deploy to environment
        env:
          ENVIRONMENT: ${{ inputs.environment }}
          VERSION: ${{ inputs.version }}
        run: |
          echo "Deploying $VERSION to $ENVIRONMENT"
          ./scripts/deploy.sh "$ENVIRONMENT" "$VERSION"

      - name: Notify deployment
        if: always() && secrets.slack_webhook != ''
        env:
          SLACK_WEBHOOK: ${{ secrets.slack_webhook }}
          ENVIRONMENT: ${{ inputs.environment }}
          VERSION: ${{ inputs.version }}
          STATUS: ${{ job.status }}
        run: |
          curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"Deployment $STATUS: $VERSION to $ENVIRONMENT\"}"

```

**Caller Workflow**:

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]
    tags: ['v*']

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    uses: org/workflows/.github/workflows/reusable-deploy-secure.yml@a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0  # v2.1.0
    with:
      environment: production
      version: ${{ github.ref_name }}
    secrets:
      wif_provider: ${{ secrets.WIF_PROVIDER }}
      wif_service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
      slack_webhook: ${{ secrets.SLACK_WEBHOOK }}
```

**Security Features**:

1. Choice input for environment with fixed values
2. String input with regex validation for version
3. Explicit secret passing (no `secrets: inherit`)
4. Caller repository allowlist validation
5. SHA-pinned workflow reference in caller
6. Environment protection gates
7. OIDC authentication (no stored cloud credentials)
8. Minimal GITHUB_TOKEN permissions

## Security Best Practices

1. **Always pin to SHA**: Never use branch or tag references for reusable workflows in production
2. **Validate all inputs**: Use `choice` type or runtime validation for string inputs
3. **Explicit secrets only**: Avoid `secrets: inherit`, declare required secrets explicitly
4. **Restrict callers**: Validate `github.repository` to allowlist authorized callers
5. **Minimal permissions**: Declare minimal `permissions` block in reusable workflow
6. **Environment protection**: Use environment gates for deployment workflows
7. **Prefer OIDC**: Use Workload Identity Federation instead of stored secrets
8. **Document requirements**: Clear descriptions for inputs and secrets
9. **Audit usage**: Monitor which repositories call shared workflows
10. **Version workflows**: Tag reusable workflows with semantic versions

## Common Mistakes

### Mistake 1: Unpinned Workflow Reference

**Problem**: Branch reference allows supply chain attacks

```yaml
# DANGEROUS
jobs:
  deploy:
    uses: org/workflows/.github/workflows/deploy.yml@main
```

**Fix**: Pin to SHA

```yaml
jobs:
  deploy:
    uses: org/workflows/.github/workflows/deploy.yml@a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0  # v1.2.3
```

### Mistake 2: Unvalidated String Input

**Problem**: Command injection via unvalidated input

```yaml
# DANGEROUS
on:
  workflow_call:
    inputs:
      command:
        type: string
jobs:
  run:
    steps:
      - run: ${{ inputs.command }}
```

**Fix**: Validate input or use choice type

```yaml
on:
  workflow_call:
    inputs:
      task:
        type: choice
        options: [build, test, deploy]
jobs:
  run:
    steps:
      - name: Validate task
        run: |
          case "${{ inputs.task }}" in
            build|test|deploy) ;;
            *) exit 1 ;;
          esac
      - run: ./scripts/${{ inputs.task }}.sh
```

### Mistake 3: Using `secrets: inherit`

**Problem**: Excessive secret exposure

```yaml
# DANGEROUS
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml@main
    secrets: inherit
```

**Fix**: Explicit secret passing

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml@a1b2c3d4e5f6
    secrets:
      deploy_key: ${{ secrets.DEPLOY_KEY }}
```

### Mistake 4: No Caller Validation

**Problem**: Any repository can call workflow

**Fix**: Add caller allowlist

```yaml
jobs:
  validate:
    steps:
      - run: |
          if [[ "${{ github.repository }}" != "org/allowed-repo" ]]; then
            exit 1
          fi
```

## Troubleshooting

| Issue | Cause | Solution |
| ----- | ----- | -------- |
| Workflow not found | Incorrect path or SHA | Verify workflow exists at `.github/workflows/` in referenced commit |
| Input validation failed | Invalid input format | Check input against validation rules in reusable workflow |
| Secret not available | Secret not passed or wrong name | Verify secret name matches between caller and reusable workflow |
| Caller validation failed | Repository not in allowlist | Add repository to allowed repositories list |
| Permission denied | Insufficient GITHUB_TOKEN permissions | Check `permissions` block in both caller and reusable workflow |
| Environment protection blocks | Missing approval or branch policy | Configure environment protection rules or approve deployment |

## Quick Reference

### Input Type Selection

| Input Data | Type | Validation |
| ---------- | ---- | ---------- |
| Fixed set of values | `choice` | Automatic |
| Environment name | `environment` | GitHub validates |
| Free text | `string` | Runtime validation required |
| Version number | `string` | Regex validation |
| Feature flag | `boolean` | Type validated |
| Count/index | `number` | Range validation |

### Secret Passing Patterns

| Pattern | Risk | Use Case |
| ------- | ---- | -------- |
| No secrets | Minimal | OIDC-only workflows |
| Explicit secrets | Low | Production workflows |
| `secrets: inherit` | High | Trusted internal workflows only |

### Reusable Workflow Security Checklist

- [ ] Workflow pinned to SHA in caller (not branch/tag)
- [ ] All string inputs validated with allowlist or regex
- [ ] Secrets passed explicitly (no `secrets: inherit`)
- [ ] Caller repository validated against allowlist
- [ ] Minimal `permissions` block declared
- [ ] Environment protection for deployments
- [ ] OIDC preferred over stored secrets
- [ ] Input and secret requirements documented
- [ ] Version tag added for tracking
- [ ] Dependabot configured for updates

## Related Pages

- [Workflow Trigger Security](./triggers.md) - `workflow_call` vs other triggers, event security
- [Environment Protection Patterns](./environments.md) - Deployment gates for reusable workflows
- [Token Permissions](../token-permissions/index.md) - Permission inheritance in reusable workflows
- [Secret Management](../secrets/index.md) - Secret scoping and OIDC patterns
- [Action Pinning](../action-pinning/sha-pinning.md) - SHA pinning strategy for dependencies
