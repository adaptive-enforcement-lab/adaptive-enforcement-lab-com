---
title: Environment Progression Testing
description: >-
  Progressive deployment validation with Kustomize overlays, Argo CD automation, load testing in staging, and rollback strategies for Kubernetes environments.
---

# Environment Progression Testing

Same manifests, different configs:

!!! tip "Environment Progression"
    Progressive deployment validation. Start with local validation before enabling CI enforcement.

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
spec:
  replicas: 1  # Override per environment
  template:
    spec:
      containers:
        - name: api
          image: gcr.io/project/api:IMAGE_TAG
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: url
```

Kustomize overlays for each environment:

```yaml
# overlays/dev/kustomization.yaml
bases:
  - ../../base
namePrefix: dev-
namespace: development
replicas:
  - name: api
    count: 1
images:
  - name: gcr.io/project/api
    newTag: latest

# overlays/production/kustomization.yaml
bases:
  - ../../base
namePrefix: prod-
namespace: production
replicas:
  - name: api
    count: 10
images:
  - name: gcr.io/project/api
    newTag: v1.2.3  # Pinned version
```

Deploy:

```bash
kubectl apply -k overlays/dev
kubectl apply -k overlays/production
```

---

## Progressive Rollout with Argo CD

Argo CD automates the progression:

```yaml
# Application for dev
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-dev
spec:
  source:
    repoURL: https://github.com/org/manifests
    path: overlays/dev
  destination:
    namespace: development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true

# Application for production
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: api-production
spec:
  source:
    repoURL: https://github.com/org/manifests
    path: overlays/production
  destination:
    namespace: production
  syncPolicy:
    automated:
      prune: false  # Manual approval required
      selfHeal: true
  syncOptions:
    - CreateNamespace=false
```

Dev auto-syncs. Production requires approval.

---

## Load Testing in Staging

Staging should simulate production load:

```yaml
# .github/workflows/load-test.yml
jobs:
  load-test:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - name: Run k6 load test
        run: |
          k6 run --vus 100 --duration 5m loadtest.js

# loadtest.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export default function() {
  const res = http.get('https://staging.example.com/api/health');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}
```

Staging handles 100 concurrent users for 5 minutes? Production probably can too.

---

## Database Migrations

Test migrations in staging with production-scale data:

```yaml
jobs:
  migrate-staging:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - name: Backup staging DB
        run: |
          pg_dump -h staging-db > backup.sql

      - name: Run migration
        run: |
          kubectl exec -n staging deploy/api -- /app/migrate

      - name: Verify migration
        run: |
          kubectl exec -n staging deploy/api -- /app/verify-schema

      - name: Smoke test after migration
        run: ./scripts/smoke-test.sh https://staging.example.com

  migrate-production:
    needs: migrate-staging
    environment: production
    runs-on: ubuntu-latest
    steps:
      - name: Backup production DB
        run: |
          pg_dump -h prod-db > backup-$(date +%Y%m%d).sql
          gsutil cp backup-*.sql gs://backups/

      - name: Run migration
        run: |
          kubectl exec -n production deploy/api -- /app/migrate
```

Migration works in staging? Confidence for production.

---

## Rollback Strategy

Every deployment needs a rollback plan:

```bash
# Rollback script
#!/usr/bin/env bash

NAMESPACE=$1
DEPLOYMENT=$2
REVISION=${3:-1}  # Default to previous revision

echo "Rolling back $DEPLOYMENT in $NAMESPACE to revision -$REVISION"

kubectl rollout undo deployment/$DEPLOYMENT \
  -n $NAMESPACE \
  --to-revision=$(($(kubectl rollout history deployment/$DEPLOYMENT -n $NAMESPACE | wc -l) - REVISION))

# Wait for rollback
kubectl rollout status deployment/$DEPLOYMENT -n $NAMESPACE

# Verify with smoke test
./scripts/smoke-test.sh https://$NAMESPACE.example.com
```

Automate rollback on smoke test failure:

```yaml
- name: Deploy to production
  run: kubectl apply -f manifests/ -n production

- name: Smoke test
  id: smoke
  run: ./scripts/smoke-test.sh https://example.com

- name: Rollback on failure
  if: failure() && steps.smoke.conclusion == 'failure'
  run: kubectl rollout undo deployment/api -n production
```

---

## Next Steps

For operational patterns including feature flags, monitoring, and quality gates, see **[Environment Progression Operations](environment-progression-operations.md)**.

For related SDLC patterns:

- **[SDLC Hardening](../../blog/posts/2025-12-12-harden-sdlc-before-audit.md)** - Build security into pipelines
- **[Zero-Vulnerability Pipelines](../../blog/posts/2025-12-15-zero-vulnerability-pipelines.md)** - Scan before each environment
- **[Policy-as-Code with Kyverno](../../blog/posts/2025-12-13-policy-as-code-kyverno.md)** - Enforce standards per environment

---

*Progressive deployment validation prevents production incidents. Test in dev, validate in staging, deploy to production with confidence.*
