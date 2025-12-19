---
title: Workflow Orchestration Examples
description: >-
  Apply separation of concerns to Argo Workflows and GitHub Actions. Isolate step execution from orchestration logic for testable, reusable workflows.
---

# Workflow Orchestration Examples

!!! tip "Quick Start"
    This guide shows practical examples of separation of concerns in workflow orchestration. See [Pattern Overview](index.md) for core concepts.

## Argo Workflows Example

**Separate workflow orchestration from step execution:**

```go
// pkg/workflow/orchestrator.go
package workflow

import (
    "context"
    "fmt"
)

// Step represents a workflow step
type Step interface {
    Name() string
    Execute(ctx context.Context) error
    Rollback(ctx context.Context) error
}

// Orchestrator coordinates workflow execution
type Orchestrator struct {
    steps    []Step
    logger   Logger
    executed []Step  // Track for rollback
}

func NewOrchestrator(steps []Step, logger Logger) *Orchestrator {
    return &Orchestrator{
        steps:  steps,
        logger: logger,
    }
}

// Run executes all steps sequentially
func (o *Orchestrator) Run(ctx context.Context) error {
    for _, step := range o.steps {
        o.logger.Info(fmt.Sprintf("Executing step: %s", step.Name()))

        if err := step.Execute(ctx); err != nil {
            o.logger.Error(fmt.Errorf("step %s failed: %w", step.Name(), err))

            // Rollback executed steps in reverse
            if rbErr := o.rollback(ctx); rbErr != nil {
                return fmt.Errorf("step failed and rollback failed: %w (rollback: %v)", err, rbErr)
            }

            return fmt.Errorf("step %s failed: %w", step.Name(), err)
        }

        o.executed = append(o.executed, step)
    }

    return nil
}

// rollback executes rollback in reverse order
func (o *Orchestrator) rollback(ctx context.Context) error {
    for i := len(o.executed) - 1; i >= 0; i-- {
        step := o.executed[i]
        o.logger.Info(fmt.Sprintf("Rolling back step: %s", step.Name()))

        if err := step.Rollback(ctx); err != nil {
            return fmt.Errorf("rollback %s failed: %w", step.Name(), err)
        }
    }
    return nil
}
```

**Step implementations are isolated:**

```go
// pkg/workflow/steps/validate.go
package steps

import (
    "context"
    "fmt"
)

type ValidateStep struct {
    config *Config
}

func (s *ValidateStep) Name() string {
    return "validate-config"
}

func (s *ValidateStep) Execute(ctx context.Context) error {
    if s.config.Name == "" {
        return fmt.Errorf("name required")
    }

    if s.config.Image == "" {
        return fmt.Errorf("image required")
    }

    return nil
}

func (s *ValidateStep) Rollback(ctx context.Context) error {
    // Validation has no side effects, nothing to rollback
    return nil
}
```

```go
// pkg/workflow/steps/deploy.go
package steps

import (
    "context"
    "fmt"

    "k8s.io/client-go/kubernetes"
)

type DeployStep struct {
    client    kubernetes.Interface
    config    *Config
    deployed  bool
}

func (s *DeployStep) Name() string {
    return "deploy-to-kubernetes"
}

func (s *DeployStep) Execute(ctx context.Context) error {
    deployment := buildDeployment(s.config)

    _, err := s.client.AppsV1().Deployments(s.config.Namespace).Create(
        ctx, deployment, metav1.CreateOptions{},
    )
    if err != nil {
        return fmt.Errorf("creating deployment: %w", err)
    }

    s.deployed = true
    return nil
}

func (s *DeployStep) Rollback(ctx context.Context) error {
    if !s.deployed {
        return nil  // Nothing deployed, nothing to rollback
    }

    return s.client.AppsV1().Deployments(s.config.Namespace).Delete(
        ctx, s.config.Name, metav1.DeleteOptions{},
    )
}
```

**CLI layer coordinates, doesn't execute:**

```go
// cmd/workflow/main.go
package main

import (
    "context"
    "fmt"
    "os"

    "github.com/spf13/cobra"
    "example.com/pkg/workflow"
    "example.com/pkg/workflow/steps"
)

func NewWorkflowCommand() *cobra.Command {
    var configPath string

    cmd := &cobra.Command{
        Use:   "workflow",
        Short: "Run deployment workflow",
        RunE: func(cmd *cobra.Command, args []string) error {
            // Parse config (CLI concern)
            config, err := loadConfig(configPath)
            if err != nil {
                return fmt.Errorf("loading config: %w", err)
            }

            // Create logger (CLI concern)
            logger := &StdLogger{verbose: true}

            // Build steps (composition)
            workflowSteps := []workflow.Step{
                &steps.ValidateStep{Config: config},
                &steps.BuildStep{Config: config},
                &steps.DeployStep{Config: config},
                &steps.VerifyStep{Config: config},
            }

            // Create orchestrator (delegates to pkg/)
            orch := workflow.NewOrchestrator(workflowSteps, logger)

            // Execute (business logic in pkg/)
            if err := orch.Run(cmd.Context()); err != nil {
                return err
            }

            // Output (CLI concern)
            fmt.Println("Workflow completed successfully")
            return nil
        },
    }

    cmd.Flags().StringVar(&configPath, "config", "config.yaml", "Config file path")
    return cmd
}
```

---

## Testing Workflow Steps

```go
// pkg/workflow/steps/deploy_test.go
package steps

import (
    "context"
    "testing"

    "k8s.io/client-go/kubernetes/fake"
)

func TestDeployStep(t *testing.T) {
    fakeClient := fake.NewSimpleClientset()

    step := &DeployStep{
        client: fakeClient,
        config: &Config{
            Name:      "test-app",
            Namespace: "default",
            Image:     "gcr.io/proj/app:v1",
        },
    }

    // Test execution
    if err := step.Execute(context.Background()); err != nil {
        t.Fatalf("Execute() failed: %v", err)
    }

    if !step.deployed {
        t.Error("expected deployed=true after Execute()")
    }

    // Test rollback
    if err := step.Rollback(context.Background()); err != nil {
        t.Fatalf("Rollback() failed: %v", err)
    }

    // Verify deployment deleted
    _, err := fakeClient.AppsV1().Deployments("default").Get(
        context.Background(), "test-app", metav1.GetOptions{},
    )
    if err == nil {
        t.Error("expected deployment to be deleted after rollback")
    }
}
```

**Benefits**:

- Orchestrator tests workflow logic without testing individual steps
- Step tests execute in isolation with fake clients
- Same steps reusable in Argo Workflows, CronJobs, or APIs
- Rollback logic separated and testable
- No Kubernetes cluster required for any tests

---

## GitHub Actions Workflow Separation

**Separate workflow orchestration from action execution:**

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        required: true

jobs:
  # Orchestration job (coordinates, doesn't execute)
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run deployment orchestrator
        run: |
          # CLI tool handles orchestration
          ./deploy-tool workflow run \
            --config config/${{ inputs.environment }}.yaml \
            --verbose
```

**Business logic in CLI tool, not in workflow YAML:**

```go
// CLI tool orchestrates, workflow just invokes
// All logic testable locally without GitHub Actions
```

**Benefits**:

- Business logic tested locally without GitHub Actions infrastructure
- Workflow YAML becomes declarative configuration, not imperative logic
- Same CLI tool works in CI/CD, CronJobs, and manual execution
- Version control and rollback of business logic separate from workflow definitions

---

## Related Guides

- **[Pattern Overview](index.md)**: Core concepts and CLI orchestrator pattern
- **[Usage Guide](guide.md)**: When to apply, common mistakes, real-world examples
- **[Implementation Techniques](implementation.md)**: Interfaces, dependency injection, testing
- **[Go CLI Architecture](../../../build/go-cli-architecture/index.md)**: Complete CLI implementation
- **[Orchestrator Pattern](../../../build/go-cli-architecture/command-architecture/orchestrator-pattern.md)**: Detailed orchestration

---

*Orchestration separated. Steps isolated. Logic testable. Workflows maintainable.*
