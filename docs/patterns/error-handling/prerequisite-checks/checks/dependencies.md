---
title: Dependency Checks
description: >-
  Dependency validation checks for upstream jobs, required artifacts, external services, and API rate limits.
tags:
  - prerequisite-checks
  - dependencies
  - validation
---
# Dependency Checks

Verify dependencies are ready.

!!! tip "Circuit Breakers for External Dependencies"
    When checking external services, implement circuit breakers to prevent cascading failures. If a dependency is consistently unavailable, fail fast instead of repeated retries.

---

## Upstream Jobs Succeeded

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: make build

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      # GitHub Actions guarantees 'build' succeeded
      # No need for explicit check
      - run: make deploy
```

---

## Required Artifacts Available

```yaml
- name: Check required artifacts
  run: |
    required=(
      "dist/app-linux-amd64.tar.gz"
      "dist/checksums.txt"
      "dist/sbom.json"
    )

    for artifact in "${required[@]}"; do
      if [ ! -f "$artifact" ]; then
        echo "::error::Required artifact missing: $artifact"
        exit 1
      fi
    done

    echo "All artifacts present"
```

---

## External Service Reachable

```go
func checkExternalDependencies(ctx context.Context) error {
    checks := map[string]func(context.Context) error{
        "database": checkDatabase,
        "cache":    checkCache,
        "api":      checkAPI,
    }

    var errors []string
    for name, check := range checks {
        if err := check(ctx); err != nil {
            errors = append(errors, fmt.Sprintf("%s: %v", name, err))
        }
    }

    if len(errors) > 0 {
        return fmt.Errorf("dependency checks failed:\n%s", strings.Join(errors, "\n"))
    }
    return nil
}

func checkDatabase(ctx context.Context) error {
    db, err := sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        return err
    }
    defer db.Close()

    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    return db.PingContext(ctx)
}
```

---

## API Rate Limits

```bash
# Check GitHub API rate limit before bulk operations
check_rate_limit() {
    local required_calls="$1"

    # Get remaining rate limit
    remaining=$(gh api rate_limit --jq '.rate.remaining')

    if (( remaining < required_calls )); then
        echo "ERROR: Insufficient rate limit"
        echo "Required: $required_calls, Available: $remaining"

        # Show reset time
        reset=$(gh api rate_limit --jq '.rate.reset')
        reset_time=$(date -r "$reset" '+%Y-%m-%d %H:%M:%S')
        echo "Rate limit resets at: $reset_time"
        return 1
    fi

    echo "Rate limit sufficient: $remaining calls remaining"
}
```

---

## Back to Prerequisites

- [Prerequisite Checks](../index.md) - Pattern overview
- [Environment Checks](environment.md) - Tools, variables, connectivity
- [Permission Checks](permissions.md) - API tokens, RBAC, IAM
- [State Checks](state.md) - Resources, health, conflicts
- [Input Validation](input.md) - Required, format, cross-field
- [Implementation Patterns](../implementation.md) - Ordering, patterns, anti-patterns
