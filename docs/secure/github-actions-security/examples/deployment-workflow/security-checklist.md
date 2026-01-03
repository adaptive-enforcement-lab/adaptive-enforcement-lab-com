---
title: Deployment Security Checklist
description: >-
  Security checklist and common deployment mistakes
---

- [ ] Deployment uses image digest (not tag) for immutability
- [ ] Health checks verify deployment before routing traffic
- [ ] Canary deployment pattern used for production
- [ ] Rollback automation tested and verified

### Monitoring and Rollback

- [ ] Post-deployment health checks verify service availability
- [ ] Canary metrics monitored (error rate, latency, throughput)
- [ ] Automatic rollback triggers on health check failure
- [ ] Manual rollback workflow available with approval gate
- [ ] Deployment logs and metrics aggregated centrally
- [ ] Alerts configured for deployment failures

### Permission Security

- [ ] Workflow-level permissions set to minimal (`contents: read`)
- [ ] Job-level `id-token: write` only on deployment jobs
- [ ] No `contents: write` unless creating releases
- [ ] `attestations: write` only on build jobs
- [ ] Service account permissions follow least privilege

## Common Mistakes and Fixes

### Mistake 1: Stored Service Account Keys

**Bad**:

```yaml
# DANGER: Long-lived service account key stored as secret
- name: Authenticate to GCP
  run: |
    echo "${{ secrets.GCP_SERVICE_ACCOUNT_KEY }}" | base64 -d > key.json
    gcloud auth activate-service-account --key-file=key.json
```

**Good**:

```yaml
# SECURITY: OIDC federation with short-lived tokens
- name: Authenticate to GCP
  uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

### Mistake 2: No Environment Protection

**Bad**:

```yaml
# DANGER: Production deployment with no approval gate
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/deploy-production.sh
```

**Good**:

```yaml
# SECURITY: Environment protection with approval gate
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production  # Requires approval in Settings → Environments
    steps:
      - run: ./scripts/deploy-production.sh
```

### Mistake 3: Immediate Traffic Routing

**Bad**:

```yaml
# DANGER: Route all traffic immediately without verification
- name: Deploy to Cloud Run
  run: |
    gcloud run deploy my-service --image gcr.io/project/image:latest
```

**Good**:

```yaml
# SECURITY: Deploy without traffic, verify, then route
- name: Deploy to Cloud Run
  run: |
    gcloud run deploy my-service \
      --image gcr.io/project/image@sha256:abc123 \
      --no-traffic  # Don't route traffic yet

- name: Verify deployment
  run: |
    # Health checks here

- name: Route traffic
  run: |
    gcloud run services update-traffic my-service --to-revisions latest=100
```

### Mistake 4: No Rollback Plan

**Bad**:

```yaml
# DANGER: Deployment with no rollback mechanism
jobs:
  deploy:
    steps:
      - run: kubectl apply -f deployment.yaml
```

**Good**:

```yaml
# SECURITY: Rollback automation on failure
jobs:
  deploy:
    steps:
      - name: Record current version
        id: current
        run: echo "version=$(kubectl get deployment my-app -o jsonpath='{.spec.template.spec.containers[0].image}')" >> $GITHUB_OUTPUT

      - name: Deploy new version
        run: kubectl apply -f deployment.yaml

      - name: Verify deployment
        run: kubectl rollout status deployment/my-app --timeout=5m

  rollback:
    needs: deploy
    if: failure()
    steps:
      - run: kubectl set image deployment/my-app app=${{ needs.deploy.steps.current.outputs.version }}
```

## Related Patterns

- **[OIDC Federation](../secrets/oidc.md)**: Complete OIDC setup for AWS, GCP, and Azure
- **[Environment Protection](../workflows/environments.md)**: Environment configuration with approval gates and wait timers
- **[Token Permissions](../token-permissions/templates.md)**: GITHUB_TOKEN permissions for deployment workflows
- **[Release Workflow](./release-workflow.md)**: Signed releases with SLSA provenance
- **[Action Pinning](../action-pinning/sha-pinning.md)**: SHA pinning patterns and Dependabot configuration

## Summary

Hardened deployment workflows require layered security controls:

1. **Eliminate secrets** with OIDC federation (no stored credentials)
2. **Require approval** for production deployments via environment protection
3. **Verify before routing** traffic with health checks and canary deployments
4. **Automate rollback** on failure to minimize downtime
5. **Monitor deployments** with metrics and alerting
6. **Attest artifacts** with SLSA provenance for supply chain security
7. **Minimize permissions** with job-level `id-token: write` only where needed

Copy these templates as starting points. Adjust environment protection rules, health checks, and canary thresholds based on your service requirements and risk tolerance.
