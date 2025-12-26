---
description: >-
  State precondition checks for resource existence, naming conflicts, service health, and system state before operations.
tags:
  - prerequisite-checks
  - state
  - validation
---

# State Preconditions

Validate system state before operations.

!!! note "Idempotency and State Checks"
    State validation helps ensure idempotent operations. Checking for existing resources prevents duplicate creation errors and enables safe retry logic.

---

## Resource Existence

```go
func validateResourcesExist(ctx context.Context, client *kubernetes.Clientset, namespace string) error {
    required := map[string]func() error{
        "ConfigMap/app-config": func() error {
            _, err := client.CoreV1().ConfigMaps(namespace).Get(ctx, "app-config", metav1.GetOptions{})
            return err
        },
        "Secret/database-credentials": func() error {
            _, err := client.CoreV1().Secrets(namespace).Get(ctx, "database-credentials", metav1.GetOptions{})
            return err
        },
        "Service/database": func() error {
            _, err := client.CoreV1().Services(namespace).Get(ctx, "database", metav1.GetOptions{})
            return err
        },
    }

    var errors []string
    for name, check := range required {
        if err := check(); err != nil {
            errors = append(errors, fmt.Sprintf("%s: %v", name, err))
        }
    }

    if len(errors) > 0 {
        return fmt.Errorf("required resources missing:\n%s", strings.Join(errors, "\n"))
    }
    return nil
}
```

---

## No Naming Conflicts

```bash
# Check for naming conflicts before creating resources
check_no_conflicts() {
    local namespace="$1"
    local deployment="$2"

    if kubectl get deployment "$deployment" -n "$namespace" &>/dev/null; then
        echo "ERROR: Deployment $deployment already exists in $namespace"
        echo "Use a different name or delete the existing deployment first"
        return 1
    fi

    echo "No naming conflicts detected"
}
```

---

## Service Health

```yaml
- name: Check dependent services
  run: |
    services=(
      "https://api.example.com/health"
      "https://database.example.com/ping"
      "https://cache.example.com/status"
    )

    for url in "${services[@]}"; do
      if ! curl -sf "$url" -o /dev/null; then
        echo "::error::Service unhealthy: $url"
        exit 1
      fi
    done

    echo "All services healthy"
```

---

## Branch Exists

```bash
# Verify target branch exists before creating PR
check_branch_exists() {
    local repo="$1"
    local branch="$2"

    if ! gh api "repos/${repo}/branches/${branch}" >/dev/null 2>&1; then
        echo "ERROR: Branch '$branch' does not exist in $repo"
        echo "Available branches:"
        gh api "repos/${repo}/branches" --jq '.[].name' | head -10
        return 1
    fi

    echo "Branch '$branch' exists"
}
```

---

## Back to Prerequisites

- [Prerequisite Checks](../index.md) - Pattern overview
- [Environment Checks](environment.md) - Tools, variables, connectivity
- [Permission Checks](permissions.md) - API tokens, RBAC, IAM
- [Input Validation](input.md) - Required, format, cross-field
- [Dependency Checks](dependencies.md) - Jobs, artifacts, services
- [Implementation Patterns](../implementation.md) - Ordering, patterns, anti-patterns
