---
title: Prerequisite Check Implementation
description: >-
  Implementation patterns for prerequisite checks including cost-based ordering, error collection strategies, and anti-patterns to avoid.
tags:
  - prerequisite-checks
  - implementation
  - patterns
---
# Prerequisite Check Implementation

Cost-based ordering, implementation patterns, and anti-patterns for prerequisite validation.

!!! note "Trade-offs: Fail-Fast vs Collect-All"
    Fail-fast provides immediate feedback but requires multiple fix-retry cycles. Collect-all shows the complete picture but takes longer to run. Choose based on your workflow and operator preferences.

---

## Check Ordering Strategy

Order checks by cost: cheapest first, most expensive last.

```yaml
- name: Prerequisite validation
  run: |
    # 1. Fast: Environment variables (milliseconds)
    [ -n "$DATABASE_URL" ] || { echo "DATABASE_URL not set"; exit 1; }
    [ -n "$API_KEY" ] || { echo "API_KEY not set"; exit 1; }

    # 2. Fast: Command existence (milliseconds)
    command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
    command -v helm >/dev/null || { echo "helm not found"; exit 1; }

    # 3. Medium: Local file checks (milliseconds)
    [ -f "helm/Chart.yaml" ] || { echo "Chart.yaml not found"; exit 1; }

    # 4. Slow: Network calls (100-500ms each)
    gh api user >/dev/null || { echo "GitHub auth failed"; exit 1; }

    # 5. Slowest: Service health (1-5s each)
    curl -sf https://api.example.com/health || { echo "API unhealthy"; exit 1; }

    echo "All prerequisites passed"
```

**Why order matters**: If environment variables are missing, no point checking service health. Fail fast on cheap checks.

---

## Implementation Patterns

### Pattern 1: Fail on First Error

```bash
validate_prerequisites() {
    # Stop at first failure
    [ -n "$DATABASE_URL" ] || { echo "DATABASE_URL not set"; return 1; }
    [ -n "$API_KEY" ] || { echo "API_KEY not set"; return 1; }
    command -v kubectl >/dev/null || { echo "kubectl not found"; return 1; }

    echo "Validation passed"
}
```

**Use when**: Fast feedback is critical, operator will fix one error at a time.

### Pattern 2: Collect All Errors

```bash
validate_prerequisites() {
    local errors=()

    # Collect all failures
    [[ -z "${DATABASE_URL:-}" ]] && errors+=("DATABASE_URL not set")
    [[ -z "${API_KEY:-}" ]] && errors+=("API_KEY not set")
    command -v kubectl >/dev/null || errors+=("kubectl not found")

    # Report everything at once
    if (( ${#errors[@]} > 0 )); then
        echo "Validation failed:"
        printf '%s\n' "${errors[@]}"
        return 1
    fi

    echo "Validation passed"
}
```

**Use when**: Operator needs full picture of what's missing.

### Pattern 3: Structured Validation

```go
type ValidationResult struct {
    Check  string
    Passed bool
    Error  error
}

func ValidatePrerequisites() ([]ValidationResult, error) {
    checks := []struct {
        name string
        fn   func() error
    }{
        {"environment", validateEnvironment},
        {"tools", validateTools},
        {"permissions", validatePermissions},
        {"state", validateState},
    }

    var results []ValidationResult
    var failed bool

    for _, check := range checks {
        err := check.fn()
        results = append(results, ValidationResult{
            Check:  check.name,
            Passed: err == nil,
            Error:  err,
        })
        if err != nil {
            failed = true
        }
    }

    if failed {
        return results, fmt.Errorf("prerequisite validation failed")
    }
    return results, nil
}
```

**Use when**: Detailed reporting needed, possibly for audit/compliance.

---

## Common CI/CD Prerequisites Checklist

### GitHub Actions Deployment

```yaml
- name: Validate prerequisites
  run: |
    errors=()

    # Environment
    [[ -n "${{ secrets.DEPLOY_TOKEN }}" ]] || errors+=("DEPLOY_TOKEN secret not configured")
    [[ -n "${{ vars.ENVIRONMENT }}" ]] || errors+=("ENVIRONMENT variable not set")

    # Tools
    command -v kubectl >/dev/null || errors+=("kubectl not installed")
    command -v helm >/dev/null || errors+=("helm not installed")

    # Permissions
    kubectl auth can-i create deployments -n production || errors+=("No permission to create deployments")

    # State
    kubectl get namespace production >/dev/null || errors+=("Namespace 'production' does not exist")

    # Resources
    helm list -n production | grep -q app-config || errors+=("app-config release not found")

    # Report
    if [ ${#errors[@]} -gt 0 ]; then
      echo "::error::Prerequisite check failed"
      printf '%s\n' "${errors[@]}"
      exit 1
    fi

    echo "All prerequisites met"
```

---

## Anti-Patterns

### 1. Checking After Side Effects

```yaml
# Bad: creates namespace before validating
- run: kubectl create namespace production
- run: |
    if ! kubectl auth can-i create deployments -n production; then
      echo "No permission"
      exit 1
    fi

# Good: validate before side effects
- run: kubectl auth can-i create deployments -n production || exit 1
- run: kubectl create namespace production
```

### 2. Vague Error Messages

```bash
# Bad
[ -f "$CONFIG_FILE" ] || exit 1

# Good
[ -f "$CONFIG_FILE" ] || {
    echo "Config file not found: $CONFIG_FILE"
    echo "Create it from: config.example.yml"
    exit 1
}
```

### 3. Expensive Checks First

```bash
# Bad: expensive check first
curl -sf https://api.example.com/health || exit 1
[ -n "$API_KEY" ] || exit 1  # Could have failed here immediately

# Good: cheap checks first
[ -n "$API_KEY" ] || exit 1
curl -sf https://api.example.com/health || exit 1
```

### 4. Checks with Side Effects

```bash
# Bad: check modifies state
if ! kubectl apply -f config.yaml --dry-run=client; then
    echo "Invalid config"
    exit 1
fi

# Good: read-only check
if ! kubectl apply -f config.yaml --dry-run=server; then
    echo "Invalid config"
    exit 1
fi
```

---

## Back to Prerequisites

- [Prerequisite Checks](index.md) - Pattern overview
- [Environment Checks](checks/environment.md) - Tools, variables, connectivity
- [Permission Checks](checks/permissions.md) - API tokens, RBAC, IAM
- [State Checks](checks/state.md) - Resources, health, conflicts
- [Input Validation](checks/input.md) - Required, format, cross-field
- [Dependency Checks](checks/dependencies.md) - Jobs, artifacts, services
