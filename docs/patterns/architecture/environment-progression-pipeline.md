---
title: Environment Progression Pipeline
description: >-
  A sequential dev, staging and production deployment workflow with smoke tests at each stage, namespace isolation and a cross-environment network policy.
provenance: human
---
# Environment Progression Pipeline

Deploy to each environment in order, and test each one before the next starts. A failure
in dev blocks staging. A failure in staging blocks production.

!!! tip "Gate on Smoke Tests"
    Each stage passes only when its smoke test passes. The production job also waits for approval.

---

## Progressive Deployment Workflow

```yaml
# .github/workflows/deploy.yml
name: Progressive Deployment

on:
  push:
    branches: [main]

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to dev
        run: kubectl apply -f manifests/ -n development
      - name: Smoke test dev
        run: ./scripts/smoke-test.sh https://dev.example.com

  deploy-staging:
    needs: deploy-dev
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to staging
        run: kubectl apply -f manifests/ -n staging
      - name: Smoke test staging
        run: ./scripts/smoke-test.sh https://staging.example.com

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production  # Requires approval
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to production
        run: kubectl apply -f manifests/ -n production
      - name: Smoke test production
        run: ./scripts/smoke-test.sh https://example.com
```

---

## Smoke Tests

Check critical paths only, not the full test suite:

```bash
#!/usr/bin/env bash
# scripts/smoke-test.sh

set -euo pipefail

URL=$1

echo "Testing $URL"

# Health check
if ! curl -sf "$URL/healthz" > /dev/null; then
    echo "❌ Health check failed"
    exit 1
fi

# API responds
if ! curl -sf "$URL/api/version" | jq -e '.version' > /dev/null; then
    echo "❌ API version check failed"
    exit 1
fi

# Database connectivity
if ! curl -sf "$URL/api/db-status" | jq -e '.connected == true' > /dev/null; then
    echo "❌ Database connection failed"
    exit 1
fi

# Critical feature works
RESPONSE=$(curl -sf -X POST "$URL/api/test-action" -d '{"test": true}')
if ! echo "$RESPONSE" | jq -e '.success == true' > /dev/null; then
    echo "❌ Critical action failed"
    exit 1
fi

echo "✅ All smoke tests passed"
```

---

## Namespace Isolation

One cluster, one namespace per environment:

```yaml
# Namespace isolation
apiVersion: v1
kind: Namespace
metadata:
  name: development
  labels:
    environment: dev
---
apiVersion: v1
kind: Namespace
metadata:
  name: staging
  labels:
    environment: staging
---
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    environment: prod
```

Deny traffic across environments:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-environment
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              environment: prod
```

---

## Related

- [Environment Progression Testing](environment-progression.md) - Overlays, Argo CD rollout, load tests and rollback
- [Environment Progression Testing (blog)](../../blog/posts/2025-12-16-environment-progression-testing.md) - The story behind the pipeline
