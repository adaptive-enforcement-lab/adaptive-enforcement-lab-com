---
title: GitHub Actions Integration
description: >-
  Implement Kyverno policy validation in GitHub Actions workflows. Automate environment detection, manifest rendering, and parallel security compliance checks.
---
# GitHub Actions Integration

GitHub Actions implementation for automated policy validation in pull requests.

## Overview

GitHub Actions workflows provide the same policy enforcement as Bitbucket Pipelines, using the policy-platform container for consistent validation.

!!! example "GitHub Actions Pattern"
    Use job-level containers with the policy-platform image. Extract environment from branch names using GitHub context variables.

---

## Complete Workflow

Equivalent implementation for GitHub Actions:

```yaml
name: Policy Validation

on:
  pull_request:
    branches:
      - development
      - staging
      - production

jobs:
  validate:
    runs-on: ubuntu-latest
    container:
      image: policy-platform:latest
      credentials:
        username: _json_key
        password: ${{ secrets.GCP_SA_KEY }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Detect Environment
        id: env
        run: |
          case ${{ github.base_ref }} in
            development) echo "ENVIRONMENT=dev" >> $GITHUB_OUTPUT ;;
            staging)     echo "ENVIRONMENT=stg" >> $GITHUB_OUTPUT ;;
            production)  echo "ENVIRONMENT=prd" >> $GITHUB_OUTPUT ;;
          esac

      - name: Render Manifests
        run: |
          helm template backend-app /repos/backend-applications/charts/backend-app \
            -f /repos/backend-applications/charts/backend-app/values.yaml \
            -f ./cd/values.${{ steps.env.outputs.ENVIRONMENT }}.yaml \
          > backend-app.yaml

          helm template security-policy /repos/security-policy/charts/security-policy \
            -f /repos/security-policy/cd/${{ steps.env.outputs.ENVIRONMENT }}/values.yaml \
          > security-policy.yaml

      - name: Validate Policies
        run: |
          kyverno apply security-policy.yaml \
            --resource backend-app.yaml \
            -t --detailed-results
```

---

## Output Examples

### Success Output

```text
Applying 12 policies to 5 resources...

pass: 60/60
fail: 0/60
warn: 0/60
error: 0/60
skip: 0/60

All resources passed policy validation!
```

### Failure Output

```text
Applying 12 policies to 5 resources...

pass: 58/60
fail: 2/60

POLICY                     RULE                    RESOURCE                RESULT
require-resource-limits    check-cpu-memory        Deployment/app/nginx    Fail
disallow-latest-tag        validate-image-tag      Deployment/app/nginx    Fail

Policy validation failed. See details above.
```

### Detailed Table Output

```text
RESOURCE                   POLICY                     RULE                  RESULT  MESSAGE
Deployment/app/nginx       require-resource-limits    check-cpu-memory      Fail    CPU and memory limits required
Deployment/app/nginx       disallow-latest-tag        validate-image-tag    Fail    Image uses :latest tag
Deployment/app/nginx       require-labels             check-standard-labels Pass    -
Deployment/app/nginx       require-probes             check-liveness-probe  Pass    -
```

---

## Policy Reports

### Downloading Reports

CI generates policy reports as artifacts. Download for detailed analysis:

**Bitbucket**: Download `policy-report.yaml` from pipeline artifacts

**GitHub Actions**: Upload artifact

```yaml
- name: Upload Policy Report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: policy-report
    path: policy-report.yaml
```

### Report Format

```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: polr-backend-app
  creationTimestamp: "2025-12-08T10:30:00Z"
results:
  - policy: require-resource-limits
    rule: check-cpu-memory
    result: fail
    severity: high
    category: Best Practices
    message: "CPU and memory limits required"
    resources:
      - apiVersion: apps/v1
        kind: Deployment
        name: nginx
        namespace: default

  - policy: disallow-latest-tag
    rule: validate-image-tag
    result: fail
    severity: medium
    category: Best Practices
    message: "Image uses :latest tag"
    resources:
      - apiVersion: apps/v1
        kind: Deployment
        name: nginx
        namespace: default
```

---

## Environment-Specific Policies

### Production Strictness

Production policies are stricter than dev:

**dev/values.yaml** (relaxed):

```yaml
policies:
  resourceLimits:
    enforce: false  # Warn only in dev
  imageTag:
    allowLatest: true
```

**prd/values.yaml** (strict):

```yaml
policies:
  resourceLimits:
    enforce: true   # Block in production
  imageTag:
    allowLatest: false
```

!!! warning "Environment Drift Risk"
    CI must use the exact same environment values as runtime deployment. Mismatched values cause "works in CI, fails in production" scenarios.

**Same policies, different enforcement levels per environment.**

---

## Troubleshooting

### Policy Not Found

**Problem**: `policy 'require-resource-limits' not found`

**Cause**: Policy not rendered in manifest

**Solution**: Check Helm template output

```bash
helm template security-policy /repos/security-policy/charts/security-policy \
  -f /repos/security-policy/cd/prd/values.yaml \
| grep -A 10 "kind: ClusterPolicy"
```

### Validation Passes Locally, Fails in CI

**Problem**: Local validation succeeds, CI fails

**Cause**: Different environment values

**Solution**: Match environment in local test

```bash
# Use SAME environment values as CI
docker run --rm -v $(pwd):/workspace policy-platform:latest \
  helm template app /workspace/charts/app \
    -f /workspace/charts/app/values.yaml \
    -f /workspace/cd/values.stg.yaml \
  | kyverno apply /repos/security-policy/ --resource -
```

!!! tip "Debug Environment Mismatch"
    Compare rendered manifests locally vs CI. Use `helm template --debug` to see which values files are being used.

### Container Authentication Fails

**Problem**: `unauthorized: authentication required`

**Cause**: Missing or expired credentials

**Solution**: Set credentials in CI variables

```yaml
image:
  name: policy-platform:latest
  username: _json_key
  password: $GCLOUD_API_KEYFILE  # CI variable
```

---

## Best Practices

### 1. Use Same Container Everywhere

Local dev, CI, and runtime should use **identical policy versions**.

### 2. Generate Policy Reports

Always create artifacts for detailed review:

```bash
kyverno apply policy.yaml --resource app.yaml --policy-report > report.yaml
```

### 3. Fail Fast

Validate schemas before rendering manifests. Don't waste time on invalid inputs.

### 4. Parallel Validation

Run independent policy checks in parallel. DevOps and Security policies don't depend on each other.

### 5. Environment-Specific Values

Don't apply production policies to dev. Allow progressive strictness.

---

## Next Steps

- **[Runtime Deployment](../runtime-deployment/index.md)** - Deploy Kyverno admission control
- **[Multi-Source Policies](../multi-source-policies/index.md)** - Aggregate multiple policy repos
- **[Policy Packaging](../policy-packaging/index.md)** - Build policy-platform container
- **[Operations](../operations/index.md)** - Day-to-day policy management
