---
title: Kyverno Testing and Exceptions
description: >-
  Test policies with Kyverno CLI before production deployment. Manage exceptions
  and exclusions. Troubleshoot common policy failures.
---

# Kyverno Testing and Exceptions

Test policies locally before enforcing in production. Manage exceptions for special cases. Debug policy failures efficiently.

---

## Local Testing with Kyverno CLI

Test before production using Kyverno CLI:

```bash
# Install kyverno CLI
brew install kyverno

# Test policy against manifest
kyverno apply policy.yaml --resource deployment.yaml

# Expected output
Applying 1 policy to 1 resource...
policy require-resource-limits -> resource Deployment/default/api failed
```

### Test Workflow

```bash
# 1. Create test manifests
mkdir -p tests/{valid,invalid}

# 2. Valid manifest (should pass)
cat > tests/valid/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  labels:
    team: backend
    environment: production
    cost-center: engineering
spec:
  template:
    spec:
      containers:
      - name: app
        image: gcr.io/project/api:v1.0.0
        resources:
          limits:
            memory: "512Mi"
            cpu: "500m"
EOF

# 3. Invalid manifest (should fail)
cat > tests/invalid/deployment.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  # Missing required labels
spec:
  template:
    spec:
      containers:
      - name: app
        image: docker.io/library/nginx:latest  # Unapproved registry + latest tag
        # Missing resource limits
EOF

# 4. Run tests
kyverno apply policies/ --resource tests/valid/ || echo "Valid manifests failed!"
! kyverno apply policies/ --resource tests/invalid/ || echo "Invalid manifests passed!"
```

Valid manifests must pass. Invalid must fail.

---

## Container-Based Testing

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

Use policy-platform container for local development:

```bash
# Pull policy container
docker pull europe-west6-docker.pkg.dev/neon-free-ops/operations/policy-platform:latest

# Run policies against local manifests
docker run --rm \
  -v $(pwd)/manifests:/manifests \
  -v $(pwd)/policies:/policies \
  policy-platform:latest \
  kyverno apply /policies --resource /manifests
```

Container includes:

- Kyverno CLI
- Pluto (deprecated API checker)
- Helm lint tools

---

## Integration Test in CI

```yaml
# .github/workflows/policy-test.yml
name: Policy Validation
on: [push]
jobs:
  test-policies:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Kyverno CLI
        run: |
          brew install kyverno

      - name: Test valid manifests
        run: |
          for policy in policies/*.yaml; do
            kyverno apply $policy \
              --resource manifests/valid/ \
              || exit 1
          done

      - name: Test invalid manifests (must fail)
        run: |
          for policy in policies/*.yaml; do
            ! kyverno apply $policy \
              --resource manifests/invalid/ \
              || exit 1
          done
```

---
