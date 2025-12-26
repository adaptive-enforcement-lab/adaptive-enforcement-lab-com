---
description: >-
  Environment validation checks for required tools, variables, and network connectivity before deployment or automation tasks.
tags:
  - prerequisite-checks
  - environment
  - validation
---

# Environment Validation

Check that the environment has everything needed before starting work.

!!! tip "Check Environment Early"
    Validate tools, variables, and connectivity before expensive operations. Failing fast on missing environment variables saves time and prevents partial deployments.

---

## Required Environment Variables

```bash
#!/bin/bash
set -euo pipefail

validate_environment() {
    local errors=()

    # Required variables
    [[ -z "${DATABASE_URL:-}" ]] && errors+=("DATABASE_URL not set")
    [[ -z "${API_KEY:-}" ]] && errors+=("API_KEY not set")
    [[ -z "${DEPLOY_ENV:-}" ]] && errors+=("DEPLOY_ENV not set")

    # Valid values
    if [[ -n "${DEPLOY_ENV:-}" ]]; then
        [[ "$DEPLOY_ENV" =~ ^(dev|staging|prod)$ ]] || errors+=("DEPLOY_ENV must be dev, staging, or prod")
    fi

    # Report all errors
    if (( ${#errors[@]} > 0 )); then
        echo "Environment validation failed:"
        printf '%s\n' "${errors[@]}"
        return 1
    fi

    echo "Environment validation passed"
}

validate_environment
```

---

## Required Tools Installed

```yaml
# GitHub Actions prerequisite check
- name: Validate prerequisites
  run: |
    errors=()

    # Check tools
    command -v kubectl >/dev/null || errors+=("kubectl not installed")
    command -v helm >/dev/null || errors+=("helm not installed")
    command -v jq >/dev/null || errors+=("jq not installed")

    # Check versions
    kubectl_version=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
    [[ "$kubectl_version" == v1.28.* ]] || errors+=("kubectl version must be 1.28.x, got $kubectl_version")

    # Report errors
    if [ ${#errors[@]} -gt 0 ]; then
      printf '%s\n' "${errors[@]}"
      exit 1
    fi

    echo "All prerequisites met"
```

---

## Network Connectivity

```go
func validateConnectivity() error {
    endpoints := []string{
        "https://api.github.com",
        "https://registry.npmjs.org",
        "https://gcr.io",
    }

    var errors []string
    for _, endpoint := range endpoints {
        if err := pingEndpoint(endpoint); err != nil {
            errors = append(errors, fmt.Sprintf("%s: %v", endpoint, err))
        }
    }

    if len(errors) > 0 {
        return fmt.Errorf("connectivity check failed:\n%s", strings.Join(errors, "\n"))
    }
    return nil
}

func pingEndpoint(url string) error {
    client := http.Client{Timeout: 5 * time.Second}
    resp, err := client.Head(url)
    if err != nil {
        return err
    }
    defer resp.Body.Close()

    if resp.StatusCode >= 400 {
        return fmt.Errorf("HTTP %d", resp.StatusCode)
    }
    return nil
}
```

---

## Back to Prerequisites

- [Prerequisite Checks](../index.md) - Pattern overview
- [Permission Checks](permissions.md) - API tokens, RBAC, IAM
- [State Checks](state.md) - Resources, health, conflicts
- [Input Validation](input.md) - Required, format, cross-field
- [Dependency Checks](dependencies.md) - Jobs, artifacts, services
- [Implementation Patterns](../implementation.md) - Ordering, patterns, anti-patterns
