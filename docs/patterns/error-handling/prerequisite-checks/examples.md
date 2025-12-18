---
description: >-
  Production-ready prerequisite validation code for Kubernetes deployments, GitHub Actions workflows, database migrations, and Go applications with structured gates.
---

# Prerequisite Check Examples

Real-world implementations of prerequisite validation patterns.

!!! example "Production-Ready Code"
    These examples are extracted from production systems and demonstrate the check-then-execute pattern across different environments.

---

## Kubernetes Deployment Prerequisites

```bash
#!/bin/bash
set -euo pipefail

check_prerequisites() {
    local namespace="$1"
    local errors=()

    echo "Checking prerequisites for deployment to $namespace..."

    # Tool checks
    command -v kubectl >/dev/null 2>&1 || errors+=("kubectl not found")
    command -v helm >/dev/null 2>&1 || errors+=("helm not found")
    command -v jq >/dev/null 2>&1 || errors+=("jq not found")

    # Access checks
    kubectl auth can-i create deployments -n "$namespace" >/dev/null 2>&1 \
        || errors+=("No permission to create deployments in $namespace")
    kubectl auth can-i create services -n "$namespace" >/dev/null 2>&1 \
        || errors+=("No permission to create services in $namespace")

    # State checks
    kubectl get namespace "$namespace" >/dev/null 2>&1 \
        || errors+=("Namespace $namespace does not exist")

    # Resource checks
    local available_memory
    available_memory=$(kubectl top nodes --no-headers | awk '{sum+=$4} END {print sum}')
    [[ "$available_memory" -gt 1000 ]] \
        || errors+=("Insufficient cluster memory: ${available_memory}Mi available")

    # Report results
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Prerequisites failed:"
        printf '  - %s\n' "${errors[@]}"
        return 1
    fi

    echo "All prerequisites passed"
    return 0
}

# Gate: all prerequisites must pass before proceeding
check_prerequisites "$NAMESPACE" || exit 1

# Execution phase: safe to proceed
helm upgrade --install myapp ./chart -n "$NAMESPACE"
```

---

## GitHub Actions Prerequisite Job

```yaml
jobs:
  prerequisites:
    runs-on: ubuntu-latest
    outputs:
      ready: ${{ steps.check.outputs.ready }}
    steps:
      - uses: actions/checkout@v4

      - name: Check prerequisites
        id: check
        run: |
          errors=()

          # Check required secrets
          [ -n "${{ secrets.DEPLOY_KEY }}" ] || errors+=("DEPLOY_KEY secret not set")
          [ -n "${{ secrets.REGISTRY_TOKEN }}" ] || errors+=("REGISTRY_TOKEN secret not set")

          # Check required files
          [ -f "Dockerfile" ] || errors+=("Dockerfile not found")
          [ -f "k8s/deployment.yaml" ] || errors+=("k8s/deployment.yaml not found")

          # Check configuration
          if [ -f ".env.example" ] && [ ! -f ".env" ]; then
            errors+=(".env file missing (copy from .env.example)")
          fi

          # Report
          if [ ${#errors[@]} -gt 0 ]; then
            echo "## Prerequisites Failed" >> "$GITHUB_STEP_SUMMARY"
            for error in "${errors[@]}"; do
              echo "- $error" >> "$GITHUB_STEP_SUMMARY"
            done
            echo "ready=false" >> "$GITHUB_OUTPUT"
            exit 1
          fi

          echo "## Prerequisites Passed" >> "$GITHUB_STEP_SUMMARY"
          echo "ready=true" >> "$GITHUB_OUTPUT"

  deploy:
    needs: prerequisites
    if: needs.prerequisites.outputs.ready == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: ./deploy.sh
```

---

## Go Prerequisite Validation

```go
type DeploymentPrerequisites struct {
    KubeconfigPath string
    Namespace      string
    ImageTag       string
    DryRun         bool
}

type PrerequisiteError struct {
    Category string
    Message  string
}

func (p *DeploymentPrerequisites) Validate() []PrerequisiteError {
    var errors []PrerequisiteError

    // Configuration checks
    if p.Namespace == "" {
        errors = append(errors, PrerequisiteError{
            Category: "config",
            Message:  "namespace is required",
        })
    }
    if p.ImageTag == "" {
        errors = append(errors, PrerequisiteError{
            Category: "config",
            Message:  "image tag is required",
        })
    }

    // Tool checks
    if _, err := exec.LookPath("kubectl"); err != nil {
        errors = append(errors, PrerequisiteError{
            Category: "tools",
            Message:  "kubectl not found in PATH",
        })
    }

    // Access checks (skip if dry run)
    if !p.DryRun {
        if err := checkKubeAccess(p.KubeconfigPath, p.Namespace); err != nil {
            errors = append(errors, PrerequisiteError{
                Category: "access",
                Message:  fmt.Sprintf("kubernetes access check failed: %v", err),
            })
        }
    }

    // State checks
    if !p.DryRun {
        if !namespaceExists(p.Namespace) {
            errors = append(errors, PrerequisiteError{
                Category: "state",
                Message:  fmt.Sprintf("namespace %s does not exist", p.Namespace),
            })
        }
    }

    return errors
}

func Deploy(prereqs *DeploymentPrerequisites) error {
    // Gate: validate all prerequisites
    if errors := prereqs.Validate(); len(errors) > 0 {
        return fmt.Errorf("prerequisites failed: %v", errors)
    }

    // Execution: safe to proceed
    return executeDeployment(prereqs)
}
```

---

## Database Migration Prerequisites

```go
func CheckMigrationPrerequisites(db *sql.DB, targetVersion int) error {
    checks := []struct {
        name  string
        check func() error
    }{
        {
            name: "database connection",
            check: func() error {
                return db.Ping()
            },
        },
        {
            name: "migration lock available",
            check: func() error {
                locked, err := isMigrationLocked(db)
                if err != nil {
                    return err
                }
                if locked {
                    return errors.New("another migration is in progress")
                }
                return nil
            },
        },
        {
            name: "current version known",
            check: func() error {
                _, err := getCurrentVersion(db)
                return err
            },
        },
        {
            name: "migration files exist",
            check: func() error {
                current, _ := getCurrentVersion(db)
                for v := current + 1; v <= targetVersion; v++ {
                    if !migrationFileExists(v) {
                        return fmt.Errorf("migration file for version %d not found", v)
                    }
                }
                return nil
            },
        },
        {
            name: "backup exists",
            check: func() error {
                if !backupExistsForToday() {
                    return errors.New("no backup found for today - run backup first")
                }
                return nil
            },
        },
    }

    for _, c := range checks {
        if err := c.check(); err != nil {
            return fmt.Errorf("prerequisite '%s' failed: %w", c.name, err)
        }
    }

    return nil
}
```
