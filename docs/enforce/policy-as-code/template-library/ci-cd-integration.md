---
description: >-
  CI/CD integration for policy-as-code. GitHub Actions pre-flight validation, ArgoCD policy gating, and pre-commit hooks for automated policy enforcement in development pipelines.
tags:
  - ci-cd
  - github-actions
  - argocd
  - policy-as-code
---

# CI/CD Integration for Policy Validation

Automated policy validation in development pipelines. Catch policy violations before deployment using GitHub Actions, ArgoCD, and pre-commit hooks.

---

## GitHub Actions Pre-flight Validation

!!! tip "Fail Fast in CI/CD"
    Policy validation in CI catches violations before deployment. This is faster and cheaper than runtime rejection. Developers get immediate feedback in pull requests.

Validate policies before deployment using GitHub Actions:

```yaml
name: Policy Validation

on:
  pull_request:
    paths:
      - 'k8s/**/*.yaml'
      - 'charts/**/*.yaml'

jobs:
  kyverno-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Kyverno CLI
        run: |
          curl -sLO https://github.com/kyverno/kyverno/releases/download/v1.10.0/kyverno-cli_v1.10.0_linux_x86_64.tar.gz
          tar xf kyverno-cli_v1.10.0_linux_x86_64.tar.gz
          sudo mv kyverno /usr/local/bin/

      - name: Validate manifests against policies
        run: |
          kyverno apply ./policies/ \
            --resource k8s/**/*.yaml \
            --cluster false \
            --validate

      - name: Test Deployment manifest
        run: |
          kyverno apply ./policies/require-resource-limits.yaml \
            --resource k8s/deployment.yaml \
            --values k8s/test-values.yaml

  opa-conftest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Conftest
        uses: instrumenta/conftest-action@master
        with:
          files: k8s/**/*.yaml
          policy: policies/opa/
          options: -d

      - name: Publish test results
        if: always()
        uses: EnricoMi/publish-unit-test-result-action@v2
        with:
          files: conftest-results.xml
```

---

## ArgoCD Policy Gating

Gate deployments in ArgoCD with policy validation:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: example-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/repo
    path: k8s/
    plugin:
      name: kyverno-validator
      env:
        - name: POLICY_PATH
          value: policies/
        - name: VALIDATE_MODE
          value: "strict"
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmp-kyverno
  namespace: argocd
data:
  kyverno-validator.lua: |
    function generate(resource)
      return resource
    end

    function kyverno_validate(policies, resources)
      return os.execute(
        "kyverno apply " .. policies .. " --resource " .. resources
      )
    end
```

---

## Pre-commit Hooks

!!! warning "Pre-commit Hooks Can Be Skipped"
    Developers can bypass pre-commit hooks with `git commit --no-verify`. Use them for fast feedback, not enforcement. Real enforcement happens in CI/CD.

Validate policies locally before committing:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/kyverno/kyverno
    rev: v1.10.0
    hooks:
      - id: kyverno-validate
        name: Validate Kubernetes manifests
        entry: kyverno apply policies/ --resource
        language: system
        files: '^k8s/.*\.yaml$'
        pass_filenames: true

  - repo: local
    hooks:
      - id: conftest-validate
        name: Validate with Conftest
        entry: conftest test
        language: system
        files: '^k8s/.*\.yaml$'
        args: ['--policy', 'policies/opa/']
```

Install pre-commit hooks:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

---

## Related Resources

- **[Kyverno Templates →](kyverno-templates.md)** - Policy templates
- **[OPA Templates →](opa-templates.md)** - Constraint templates
- **[Usage Guide →](usage-guide.md)** - Customization workflow
- **[Template Library Overview →](index.md)** - Back to main page
