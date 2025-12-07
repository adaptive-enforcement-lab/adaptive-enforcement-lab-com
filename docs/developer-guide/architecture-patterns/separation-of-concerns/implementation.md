---
title: Separation of Concerns - Implementation Techniques
description: >-
  Testing isolated components, defining interface boundaries, dependency injection,
  and separating error handling from business logic.
---

# Separation of Concerns - Implementation Techniques

## Testing Benefits

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

Isolated components are testable:

```go
func TestValidateConfig(t *testing.T) {
    tests := []struct {
        name    string
        config  *AppConfig
        wantErr bool
    }{
        {
            name: "valid config",
            config: &AppConfig{
                Name:  "app",
                Image: "gcr.io/proj/app:v1",
            },
            wantErr: false,
        },
        {
            name:    "missing name",
            config:  &AppConfig{Image: "gcr.io/proj/app:v1"},
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validateConfig(tt.config)
            if (err != nil) != tt.wantErr {
                t.Errorf("validateConfig() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

No Kubernetes cluster needed. No container registry. Just pure logic testing.

---

## Interface Boundaries

Define interfaces at concern boundaries:

```go
// Parser interface
type ConfigParser interface {
    Parse(path string) (*AppConfig, error)
}

// Builder interface
type ImageBuilder interface {
    Build(ctx context.Context, config *AppConfig) error
}

// Deployer interface
type K8sDeployer interface {
    Deploy(ctx context.Context, config *AppConfig) error
}

// Orchestrator depends on interfaces
type Orchestrator struct {
    parser   ConfigParser
    builder  ImageBuilder
    deployer K8sDeployer
}
```

Benefits:

- Mock implementations for testing
- Swap implementations without changing orchestrator
- Clear contracts between components

---

## Dependency Injection

Inject dependencies instead of creating them:

```go
// Bad - creates dependencies internally
func NewOrchestrator() *Orchestrator {
    return &Orchestrator{
        parser:   &YAMLParser{},           // Tightly coupled
        builder:  &BuildahBuilder{},       // Can't test
        deployer: &KubernetesDeployer{},   // Hard to mock
    }
}

// Good - dependencies injected
func NewOrchestrator(parser ConfigParser, builder ImageBuilder, deployer K8sDeployer) *Orchestrator {
    return &Orchestrator{
        parser:   parser,
        builder:  builder,
        deployer: deployer,
    }
}

// Test with mocks
func TestOrchestrator(t *testing.T) {
    mockParser := &MockParser{}
    mockBuilder := &MockBuilder{}
    mockDeployer := &MockDeployer{}

    orchestrator := NewOrchestrator(mockParser, mockBuilder, mockDeployer)

    // Test orchestration logic without real dependencies
}
```

---

## Error Handling Separation

Keep error handling separate from business logic:

```go
// Bad - mixed concerns
func processFile(path string) error {
    data, err := os.ReadFile(path)
    if err != nil {
        log.Printf("failed to read %s: %v", path, err)
        return err
    }

    result, err := transform(data)
    if err != nil {
        log.Printf("transform failed: %v", err)
        return err
    }

    if err := save(result); err != nil {
        log.Printf("save failed: %v", err)
        return err
    }

    return nil
}

// Good - business logic separate from error reporting
func processFile(path string) error {
    data, err := readFile(path)
    if err != nil {
        return fmt.Errorf("reading file: %w", err)
    }

    result, err := transform(data)
    if err != nil {
        return fmt.Errorf("transforming: %w", err)
    }

    if err := save(result); err != nil {
        return fmt.Errorf("saving: %w", err)
    }

    return nil
}

// Caller handles logging
func main() {
    if err := processFile("data.txt"); err != nil {
        log.Fatalf("Error: %v", err)
    }
}
```

---

## Related Guides

- **[Pattern Overview](index.md)** - Core concepts and CLI orchestrator pattern
- **[Usage Guide](guide.md)** - When to apply, common mistakes, real-world examples
- **[Fail Fast](../../error-handling/fail-fast/index.md)** - Error handling at boundaries
- **[Prerequisite Checks](../../error-handling/prerequisite-checks/index.md)** - Validation separation

---

*Interfaces defined. Dependencies injected. Errors propagated cleanly. Components testable in isolation.*
