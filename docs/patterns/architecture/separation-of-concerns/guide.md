---
title: Separation of Concerns Usage Guide
description: >-
  Apply separation of concerns to CLI tools, API handlers, and workflow orchestrators. Avoid over-separation and premature abstraction in production systems.
---

# Separation of Concerns Usage Guide

## When to Apply This Pattern

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

**Always:**

- CLI tools
- API handlers
- Workflow orchestrators
- Service layers

**Especially when:**

- Multiple concerns in one function
- Testing requires external systems
- Changes ripple across unrelated code
- New team members struggle to understand flow

---

## Common Mistakes

### Mistake 1: Over-Separation

```go
// Too granular
func getFirstName(user User) string { return user.FirstName }
func getLastName(user User) string { return user.LastName }
func formatName(first, last string) string { return first + " " + last }

// Reasonable
func getFullName(user User) string {
    return fmt.Sprintf("%s %s", user.FirstName, user.LastName)
}
```

Separation is about logical concerns, not individual operations.

### Mistake 2: Premature Abstraction

Don't separate concerns that don't exist yet. Wait until you have two different concerns before splitting.

### Mistake 3: Wrong Boundaries

```go
// Bad: cuts across natural boundaries
func parseAndValidate(path string) (*Config, error)  // Parser + validator mixed

// Good: natural boundaries
func parse(path string) (*Config, error)
func validate(config *Config) error
```

---

---

## Anti-Patterns

### ❌ Business Logic in Command Handlers

```go
// Bad: Business logic trapped in CLI layer
func NewDeployCommand() *cobra.Command {
    return &cobra.Command{
        Use: "deploy",
        RunE: func(cmd *cobra.Command, args []string) error {
            namespace, _ := cmd.Flags().GetString("namespace")
            image, _ := cmd.Flags().GetString("image")

            // ❌ Validation logic in CLI handler
            if image == "" || namespace == "" {
                return fmt.Errorf("missing required flags")
            }

            // ❌ Kubernetes logic in CLI handler
            config, _ := clientcmd.BuildConfigFromFlags("", kubeconfig)
            clientset, _ := kubernetes.NewForConfig(config)

            // ❌ Deployment creation in CLI handler
            deployment := &appsv1.Deployment{/* ... */}
            _, err := clientset.AppsV1().Deployments(namespace).Create(
                context.Background(), deployment, metav1.CreateOptions{},
            )

            return err
        },
    }
}
```

**Problems**:

- Cannot test without Kubernetes cluster
- Cannot reuse from API or CronJob
- Cannot mock Kubernetes client for testing
- Violates single responsibility principle

**Fix**: Move business logic to `pkg/deployer`, keep only CLI concerns in `cmd/`.

---

### ❌ Tight Coupling to CLI Framework

```go
// Bad: Passing Cobra command to business logic
package deployer

func Deploy(cmd *cobra.Command, namespace string) error {
    // ❌ Business logic depends on Cobra
    verbose, _ := cmd.Flags().GetBool("verbose")
    if verbose {
        fmt.Println("Starting deployment...")
    }

    // Deployment logic...
}
```

**Problems**:

- Business logic tied to Cobra
- Cannot use deployer from non-CLI contexts
- Tests require Cobra command setup

**Fix**: Pass plain values, not framework types. Use interfaces for output.

```go
// Good: Framework-agnostic interface
package deployer

type Logger interface {
    Info(msg string)
    Error(msg string)
}

func Deploy(namespace string, logger Logger) error {
    logger.Info("Starting deployment...")
    // Deployment logic...
}
```

---

### ❌ Wrong Layer Boundaries

```go
// Bad: Cutting across natural boundaries
package app

// ❌ Parser and validator mixed
func LoadAndValidateConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var config Config
    if err := yaml.Unmarshal(data, &config); err != nil {
        return nil, err
    }

    // Validation mixed with parsing
    if config.Name == "" {
        return nil, fmt.Errorf("name required")
    }

    return &config, nil
}
```

**Problems**:

- Cannot test validation independently
- Cannot reuse parser with different validators
- Changes to validation require touching parser

**Fix**: Separate into distinct responsibilities.

```go
// Good: Natural boundaries
package parser

func Load(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var config Config
    if err := yaml.Unmarshal(data, &config); err != nil {
        return nil, err
    }

    return &config, nil
}

package validator

func Validate(config *Config) error {
    if config.Name == "" {
        return fmt.Errorf("name required")
    }
    return nil
}
```

---

### ❌ Missing Abstraction at Boundaries

```go
// Bad: Direct dependency on concrete implementation
package orchestrator

import "example.com/internal/k8s"

type Orchestrator struct {
    // ❌ Concrete type, cannot mock
    deployer *k8s.Deployer
}

func (o *Orchestrator) Run() error {
    return o.deployer.Deploy()
}
```

**Problems**:

- Cannot mock deployer for testing
- Cannot swap implementations
- Tight coupling to Kubernetes

**Fix**: Use interfaces at boundaries.

```go
// Good: Interface at boundary
package orchestrator

type Deployer interface {
    Deploy(ctx context.Context) error
}

type Orchestrator struct {
    deployer Deployer  // Interface, easily mocked
}

func (o *Orchestrator) Run(ctx context.Context) error {
    return o.deployer.Deploy(ctx)
}
```

---

## cmd/ vs pkg/ Structure Examples

### CLI Tools

**Correct structure for deployment CLI**:

```text
deploy-tool/
├── cmd/
│   └── deploy/
│       └── main.go              # Cobra setup, flag parsing
├── pkg/
│   ├── deployer/
│   │   ├── deployer.go          # Deployment orchestration
│   │   └── deployer_test.go     # Unit tests (no cluster)
│   ├── validator/
│   │   ├── validator.go         # Config validation
│   │   └── validator_test.go    # Pure logic tests
│   └── k8s/
│       ├── client.go            # Kubernetes client wrapper
│       └── fake.go              # Fake client for testing
└── internal/
    └── config/
        └── loader.go            # Config file parsing
```

**What goes where**:

| Concern | Location | Example |
|---------|----------|---------|
| Flag definitions | `cmd/` | `cmd.Flags().StringVar(&opts.Namespace, "namespace", "default", "")` |
| Output formatting | `cmd/` | `fmt.Printf("Deployed %s\n", result.Name)` |
| Exit codes | `cmd/` | `os.Exit(1)` or `return err` from RunE |
| Validation logic | `pkg/validator/` | `func Validate(config *Config) error` |
| Deployment logic | `pkg/deployer/` | `func (d *Deployer) Deploy(ctx context.Context) error` |
| Kubernetes API calls | `pkg/k8s/` | Wrapped client interface |
| Config parsing | `internal/config/` | `func Load(path string) (*Config, error)` |

---

### Workflow Orchestration

**Correct structure for multi-step workflow**:

```text
workflow-tool/
├── cmd/
│   └── run/
│       └── main.go              # CLI entry point
├── pkg/
│   ├── orchestrator/
│   │   ├── orchestrator.go      # Workflow coordination
│   │   └── orchestrator_test.go # Integration tests
│   ├── steps/
│   │   ├── validate.go          # Step: Validation
│   │   ├── build.go             # Step: Build
│   │   ├── deploy.go            # Step: Deploy
│   │   └── verify.go            # Step: Verification
│   └── executor/
│       ├── executor.go          # Step execution framework
│       └── mock.go              # Mock executor for testing
```

**Orchestrator delegates to steps**:

```go
// pkg/orchestrator/orchestrator.go
type Orchestrator struct {
    executor executor.Executor
    steps    []Step
}

func (o *Orchestrator) Run(ctx context.Context) error {
    for _, step := range o.steps {
        if err := o.executor.Execute(ctx, step); err != nil {
            return fmt.Errorf("step %s failed: %w", step.Name(), err)
        }
    }
    return nil
}
```

---

## Real-World Example

See [Go CLI Architecture](../../../build/go-cli-architecture/command-architecture/orchestrator-pattern.md) for complete implementation of the orchestrator pattern with testing strategies.

---

## Related Patterns

- **[Pattern Overview](index.md)**: Core concepts and CLI orchestrator pattern
- **[Implementation Techniques](implementation.md)**: Testing, interfaces, dependency injection
- **[Hub and Spoke](../hub-and-spoke/index.md)**: Distributed version of orchestration
- **[Fail Fast](../../error-handling/fail-fast/index.md)**: Error handling at boundaries
- **[Prerequisite Checks](../../error-handling/prerequisite-checks/index.md)**: Validation separation
- **[Three-Stage Design](../three-stage-design.md)**: Discovery → Execution → Summary pattern

---

*Each component does one thing well. Changes are isolated. Tests run in milliseconds. The system is maintainable.*
