---
description: >-
  Input validation checks for required fields, formats, and cross-field validation before processing data or operations.
tags:
  - prerequisite-checks
  - input-validation
  - validation
---

# Input Validation

Validate all inputs before processing.

!!! warning "Security: Always Validate Untrusted Input"
    Never trust user input. Validate format, length, and content before processing. Sanitize data to prevent injection attacks (SQL, command, XSS).

---

## Required Inputs Provided

```go
type DeployRequest struct {
    Environment string `json:"environment"`
    Version     string `json:"version"`
    Replicas    int    `json:"replicas"`
}

func (r *DeployRequest) Validate() error {
    var errors []string

    // Required fields
    if r.Environment == "" {
        errors = append(errors, "environment is required")
    }
    if r.Version == "" {
        errors = append(errors, "version is required")
    }

    // Valid values
    validEnvs := map[string]bool{"dev": true, "staging": true, "prod": true}
    if !validEnvs[r.Environment] {
        errors = append(errors, fmt.Sprintf("invalid environment: %s (must be dev, staging, or prod)", r.Environment))
    }

    // Value bounds
    if r.Replicas < 1 || r.Replicas > 100 {
        errors = append(errors, fmt.Sprintf("replicas must be 1-100, got %d", r.Replicas))
    }

    if len(errors) > 0 {
        return fmt.Errorf("validation failed:\n- %s", strings.Join(errors, "\n- "))
    }
    return nil
}
```

---

## Format Validation

```bash
validate_semver() {
    local version="$1"

    if [[ ! "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: Invalid semver format: $version"
        echo "Expected format: v1.2.3"
        return 1
    fi

    echo "Version format valid: $version"
}

validate_email() {
    local email="$1"

    if [[ ! "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$ ]]; then
        echo "ERROR: Invalid email format: $email"
        return 1
    fi

    echo "Email format valid"
}
```

---

## Cross-Field Validation

```go
func validateDeploymentConfig(cfg *Config) error {
    // Individual field validation
    if err := cfg.Validate(); err != nil {
        return err
    }

    // Cross-field validation
    if cfg.Environment == "prod" && cfg.Replicas < 3 {
        return fmt.Errorf("production deployments require at least 3 replicas, got %d", cfg.Replicas)
    }

    if cfg.AutoScale && cfg.Replicas > cfg.MaxReplicas {
        return fmt.Errorf("replicas (%d) exceeds max_replicas (%d) when autoscaling enabled",
            cfg.Replicas, cfg.MaxReplicas)
    }

    if cfg.EnableTLS && cfg.CertPath == "" {
        return fmt.Errorf("cert_path required when TLS enabled")
    }

    return nil
}
```

---

## Back to Prerequisites

- [Prerequisite Checks](../index.md) - Pattern overview
- [Environment Checks](environment.md) - Tools, variables, connectivity
- [Permission Checks](permissions.md) - API tokens, RBAC, IAM
- [State Checks](state.md) - Resources, health, conflicts
- [Dependency Checks](dependencies.md) - Jobs, artifacts, services
- [Implementation Patterns](../implementation.md) - Ordering, patterns, anti-patterns
