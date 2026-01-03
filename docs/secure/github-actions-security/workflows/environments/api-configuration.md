---
title: Environment API Configuration and Best Practices
description: >-
  Automate environment configuration via GitHub API and CLI, deployment tracking patterns, and common protection rule mistakes
---

!!! tip "Automate Environment Configuration"

    Configure environments via GitHub API or CLI for consistency across repositories. Version control protection rules and audit changes. Manual configuration through web UI doesn't scale and leads to drift.

## Monitor Pending Deployments

```yaml
          GH_TOKEN: ${{ github.token }}
        run: |
          PENDING=$(gh api \
            -H "Accept: application/vnd.github+json" \
            "/repos/${{ github.repository }}/actions/runs?status=waiting&per_page=10" \
            --jq '[.workflow_runs[] | select(.updated_at < (now - 1800 | todate))] | length')

          if [ "$PENDING" -gt 0 ]; then
            echo "::warning::Deployments pending approval for >30 minutes"
          fi

```

## Security Best Practices

1. **Always use environments for production**: Never deploy to production without approval gates
2. **Combine multiple protections**: Use required reviewers AND wait timers AND branch policies
3. **Separate environment secrets**: Production credentials should never be in repository or organization secrets
4. **Prefer OIDC over stored secrets**: Use environment-scoped OIDC federation for cloud deployments
5. **Enforce branch policies**: Restrict production to protected branches only
6. **Monitor deployment history**: Alert on unusual deployment patterns or approval bypasses
7. **Document approval process**: Clear SLA for deployment approvals (e.g., 15 minutes for production)
8. **Review environment access**: Audit which teams and users can approve deployments
9. **Test environment protection**: Verify approval gates work before production use
10. **Automate rollback**: Include rollback procedures in deployment workflows

## Common Mistakes

### Mistake 1: No Environment Protection

**Problem**: Production deployment without approval gates

```yaml
# DANGEROUS - No environment protection
name: Production Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/deploy.sh production
```

**Fix**: Add environment with protection rules

```yaml
name: Production Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - run: ./scripts/deploy.sh production
```

Configure protection rules in Settings → Environments → production.

### Mistake 2: Environment Secrets Without Branch Policy

**Problem**: Any branch can access production secrets

**Fix**: Restrict environment to protected branches

Settings → Environments → production → Deployment branches → Protected branches only

### Mistake 3: Fork PR Access to Production

**Problem**: `pull_request_target` with production environment

```yaml
# DANGEROUS - Fork PRs can trigger production deployment
name: Deploy Preview
on:
  pull_request_target:

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: ./scripts/deploy.sh production
```

**Fix**: Use dedicated preview environment

```yaml
name: Deploy Preview
on:
  pull_request_target:

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: pr-previews
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: ./scripts/deploy-preview.sh
```

### Mistake 4: Single Reviewer

**Problem**: Only one reviewer required for production

**Fix**: Require multiple reviewers for production

Settings → Environments → production → Required reviewers → Add 2-3 platform team members

### Mistake 5: No Wait Timer for Critical Systems

**Problem**: Immediate production deployment without security review window

**Fix**: Add wait timer for security team monitoring

Settings → Environments → production → Wait timer → 15-30 minutes

## Troubleshooting

| Issue | Cause | Solution |
| ----- | ----- | -------- |
| Deployment pending indefinitely | Missing required reviewers | Add at least one active reviewer to environment |
| Branch policy blocks deployment | Branch not in allow-list | Add branch pattern to deployment branch policy |
| Environment secret not available | Workflow not using environment | Add `environment: name` to job configuration |
| Approval notification not sent | Reviewer email notifications disabled | Enable notifications in GitHub settings |
| Wait timer too long | Misconfigured wait timer | Reduce wait timer in environment settings |
| Fork PR cannot deploy preview | `pull_request` trigger used | Use `pull_request_target` with environment protection |

## Quick Reference

### Environment Protection Decision Matrix

| Environment | Required Reviewers | Wait Timer | Branch Policy | OIDC |
| ----------- | ------------------ | ---------- | ------------- | ---- |
| Development | No | 0 min | All branches | Optional |
| Staging | Optional | 5 min | Selected branches | Recommended |
| Production | Yes (2+) | 15-30 min | Protected only | Required |
| PR Previews | Yes (1) | 0 min | All branches | Required |

### Protection Rule Combinations

| Use Case | Protection Rules |
| -------- | ---------------- |
| Fast iteration | No protection |
| Staging deployment | Wait timer (5 min) + Branch policy |
| Production deployment | Required reviewers (2) + Wait timer (15 min) + Branch policy |
| Fork PR preview | Required reviewers (1) + OIDC |
| Critical infrastructure | Required reviewers (3) + Wait timer (30 min) + Branch policy + Audit logging |

### Environment Configuration Checklist

- [ ] Environment created for each deployment target
- [ ] Production requires 2+ reviewers
- [ ] Production wait timer configured (15-30 minutes)
- [ ] Production restricted to protected branches
- [ ] Environment secrets scoped to environment, not repository
- [ ] OIDC federation configured for cloud deployments
- [ ] Deployment tracking monitored
- [ ] Approval SLA documented
- [ ] Rollback procedures tested
- [ ] Security team has reviewer access

## Related Pages

- [Workflow Trigger Security](../triggers/index.md) - Fork PR security, `pull_request_target` patterns
- [Reusable Workflow Security](../reusable/index.md) - Environment inheritance in reusable workflows
- [OIDC Federation Patterns](../../secrets/oidc/index.md) - Secretless authentication with environment-scoped trust
- [GITHUB_TOKEN Permissions](../../token-permissions/index.md) - Minimal permissions for deployment workflows
- [Secret Management](../../secrets/secrets-management/index.md) - Environment secret scoping
