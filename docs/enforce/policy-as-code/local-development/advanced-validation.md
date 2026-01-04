---
title: Advanced Validation Patterns
description: >-
  Generate policy reports, detect deprecated APIs with Pluto, and validate Helm values with Spectral. Advanced Kyverno CLI patterns for local development.
---
# Advanced Validation Patterns

Deep-dive into policy reports, deprecated API detection, and schema validation for local development.

## Overview

Beyond basic validation, the policy-platform container supports:

- **Policy reports** - Structured YAML output for tracking
- **Audit mode** - Warn-only validation for gradual adoption
- **Deprecated API detection** - Pluto integration for cluster upgrades
- **Schema validation** - Spectral linting for Helm values

---

## Policy Report Generation

Generate detailed policy reports for review:

```bash
docker run --rm \
  -v $(pwd):/workspace \
  policy-platform:latest \
  kyverno apply /repos/security-policy/ \
    --resource /workspace/deployment.yaml \
    --policy-report \
  > policy-report.yaml
```

**policy-report.yaml**:

```yaml
apiVersion: wgpolicyk8s.io/v1alpha2
kind: PolicyReport
metadata:
  name: polr-deployment
results:
  - policy: require-resource-limits
    rule: check-cpu-memory
    result: pass
  - policy: disallow-latest-tag
    rule: validate-image-tag
    result: fail
    message: "Container uses :latest tag"
```

!!! tip "Policy Reports for Compliance"
    Policy reports are structured evidence for audit compliance. Save reports for every environment deployment as proof of validation.

---

## Table Output for CI Integration

```bash
docker run --rm \
  -v $(pwd):/workspace \
  policy-platform:latest \
  kyverno apply /repos/security-policy/ \
    --resource /workspace/deployment.yaml \
    -t --detailed-results
```

**Output**:

```text
RESOURCE                      POLICY                    RULE                RESULT
Deployment/default/nginx      require-resource-limits   check-cpu-memory    Pass
Deployment/default/nginx      disallow-latest-tag       validate-image-tag  Fail
```

---

## Audit vs Enforce Mode

Test policies in audit mode (warn-only):

```bash
docker run --rm \
  -v $(pwd):/workspace \
  policy-platform:latest \
  kyverno apply /repos/security-policy/ \
    --resource /workspace/deployment.yaml \
    --audit-warn
```

!!! note "Audit Mode for Gradual Adoption"
    Use audit mode when introducing new policies. Warnings don't fail checks. Monitor violations, fix code, then switch to enforce mode.

---

## Checking Deprecated APIs

Detect deprecated Kubernetes APIs before cluster upgrades:

```bash
docker run --rm \
  -v $(pwd):/workspace \
  policy-platform:latest \
  pluto detect /workspace/deployment.yaml
```

**Output**:

```text
NAME           KIND         VERSION      REPLACEMENT      DEPRECATED   REMOVED
ingresses      Ingress      extensions/v1beta1   networking.k8s.io/v1   v1.14.0   v1.22.0
```

### Target Version Check

Validate against specific Kubernetes versions:

```bash
docker run --rm \
  -v $(pwd):/workspace \
  policy-platform:latest \
  pluto detect /workspace/ --target-versions k8s=v1.29.0
```

!!! warning "Deprecated APIs Block Upgrades"
    Cluster upgrades to v1.29 will reject deprecated APIs. Run Pluto checks before every upgrade window.

---

## Schema Validation

### Helm Values Validation

Validate Helm values against JSON schemas:

```bash
# Merge default + environment values
docker run --rm \
  -v $(pwd):/workspace \
  policy-platform:latest \
  yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
    /workspace/charts/app/values.yaml \
    /workspace/cd/stg/values.yaml \
  > combined-values.yaml

# Validate against schema
docker run --rm \
  -v $(pwd):/workspace \
  policy-platform:latest \
  spectral lint \
    -r /workspace/.spectral.yaml \
    /workspace/combined-values.yaml
```

### Spectral Configuration

**.spectral.yaml**:

```yaml
extends: spectral:oas
rules:
  required-fields:
    given: $
    severity: error
    then:
      - field: name
        function: truthy
      - field: namespace
        function: truthy
```

**Catches**:

- Missing required fields
- Type mismatches
- Invalid enum values

---

## Next Steps

- **[Workflow Integration](workflow-integration.md)** - Pre-commit hooks and Make targets
- **[CI Integration](../ci-integration/index.md)** - Automated pipeline validation
- **[Policy Packaging](../policy-packaging/index.md)** - Build custom policy-platform containers
