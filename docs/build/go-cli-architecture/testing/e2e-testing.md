---
description: >-
  Test full CLI workflows in real Kubernetes clusters with kind and GitHub Actions. Isolated namespaces, cleanup on exit, matrix testing across versions.
---

# E2E Testing

Test full workflows in real clusters with CI/CD integration.

---

## GitHub Actions Workflow

```yaml
name: E2E Tests

on: [pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'

      - uses: helm/kind-action@v1
        with:
          cluster_name: test-cluster

      - name: Build CLI
        run: go build -o myctl ./main.go

      - name: Run E2E tests
        run: |
          kubectl create namespace e2e-test
          kubectl -n e2e-test apply -f test/fixtures/
          ./myctl orchestrate --namespace e2e-test --dry-run
```

---

## E2E Test Script

!!! warning "Always Clean Up"

    Use `trap cleanup EXIT` to ensure test namespaces are deleted even when tests fail. Orphaned resources waste cluster resources and can cause conflicts in later runs.

```bash
#!/bin/bash
# test/e2e/run.sh
set -euo pipefail

NAMESPACE="e2e-test-$(date +%s)"

cleanup() {
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
}
trap cleanup EXIT

echo "Creating test namespace: $NAMESPACE"
kubectl create namespace "$NAMESPACE"

echo "Deploying test fixtures..."
kubectl -n "$NAMESPACE" apply -f test/fixtures/

echo "Waiting for deployments..."
kubectl -n "$NAMESPACE" wait --for=condition=available deployment --all --timeout=60s

echo "Running orchestrate command..."
./myctl orchestrate --namespace "$NAMESPACE"

echo "Verifying results..."
RESTARTS=$(kubectl -n "$NAMESPACE" get pods -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}')
if [[ "$RESTARTS" != "0 0 0" ]]; then
    echo "ERROR: Unexpected restart counts: $RESTARTS"
    exit 1
fi

echo "E2E tests passed!"
```

---

## Test Fixtures

```yaml
# test/fixtures/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  labels:
    app: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
        - name: main
          image: nginx:alpine
          resources:
            limits:
              cpu: 50m
              memory: 64Mi
```

---

## Matrix Testing

Test across multiple Kubernetes versions:

```yaml
name: E2E Matrix

on: [pull_request]

jobs:
  e2e:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        k8s-version:
          - v1.28.0
          - v1.29.0
          - v1.30.0
      fail-fast: false
    steps:
      - uses: actions/checkout@v4

      - uses: helm/kind-action@v1
        with:
          node_image: kindest/node:${{ matrix.k8s-version }}
          cluster_name: test-cluster

      - name: Build and Test
        run: |
          go build -o myctl ./main.go
          ./test/e2e/run.sh
```

---

## Smoke Tests in Production

For production verification without risk:

```bash
#!/bin/bash
# Smoke test - read-only operations only
set -euo pipefail

echo "Running smoke tests..."

# Check version
./myctl version

# Check without making changes
./myctl check --json

# List without restart
./myctl select --output json

echo "Smoke tests passed!"
```

---

## Best Practices

| Practice | Description |
| ---------- | ------------- |
| **Isolated namespaces** | Create unique namespaces per test run |
| **Cleanup on exit** | Always clean up, even on failure |
| **Timeouts** | Set reasonable timeouts for resource waits |
| **Dry run first** | Test with `--dry-run` before real operations |
| **Matrix testing** | Test across multiple Kubernetes versions |

---

*E2E tests catch workflow bugs that integration tests miss.*
