---
title: Separation of Concerns - Pattern Overview
description: >-
  Single-responsibility components with clear boundaries. Orchestration separate from execution.
  Build maintainable systems through isolation.
---

# Separation of Concerns - Pattern Overview

Every component should do one thing well. Orchestration logic separated from business logic. Testability through clear boundaries.

This pattern is the foundation of maintainable systems.

---

## The Problem

Monolithic functions that do everything:

```go
func DeployApplication(ctx context.Context, config Config) error {
    // Parse config
    appConfig, err := parseYAML(config.Path)
    if err != nil {
        return err
    }

    // Validate config
    if appConfig.Name == "" {
        return errors.New("name required")
    }

    // Check cluster connection
    client, err := kubernetes.NewForConfig(kubeConfig)
    if err != nil {
        return err
    }

    // Build image
    cmd := exec.Command("buildah", "bud", "-t", appConfig.Image, ".")
    if err := cmd.Run(); err != nil {
        return err
    }

    // Push image
    cmd = exec.Command("buildah", "push", appConfig.Image, appConfig.Registry)
    if err := cmd.Run(); err != nil {
        return err
    }

    // Create deployment
    deployment := &appsv1.Deployment{...}
    _, err = client.AppsV1().Deployments(appConfig.Namespace).Create(ctx, deployment, metav1.CreateOptions{})
    if err != nil {
        return err
    }

    // Wait for ready
    for {
        dep, err := client.AppsV1().Deployments(appConfig.Namespace).Get(ctx, appConfig.Name, metav1.GetOptions{})
        if err != nil {
            return err
        }
        if dep.Status.ReadyReplicas == *dep.Spec.Replicas {
            break
        }
        time.Sleep(time.Second)
    }

    return nil
}
```

This function does six different things. Testing it requires:

- YAML files
- Kubernetes cluster
- Container registry
- Build tooling

Changing validation breaks deployment creation. Adding error handling touches everything.

---

## The Pattern

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

Separate concerns into isolated components:

```go
// Orchestrator - coordinates the flow
func DeployApplication(ctx context.Context, config Config) error {
    // Parse
    appConfig, err := parseConfig(config.Path)
    if err != nil {
        return fmt.Errorf("parsing config: %w", err)
    }

    // Validate
    if err := validateConfig(appConfig); err != nil {
        return fmt.Errorf("invalid config: %w", err)
    }

    // Build
    if err := buildImage(ctx, appConfig); err != nil {
        return fmt.Errorf("building image: %w", err)
    }

    // Push
    if err := pushImage(ctx, appConfig); err != nil {
        return fmt.Errorf("pushing image: %w", err)
    }

    // Deploy
    if err := createDeployment(ctx, appConfig); err != nil {
        return fmt.Errorf("creating deployment: %w", err)
    }

    // Wait
    if err := waitForReady(ctx, appConfig); err != nil {
        return fmt.Errorf("waiting for ready: %w", err)
    }

    return nil
}

// Each concern isolated
func parseConfig(path string) (*AppConfig, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, err
    }

    var config AppConfig
    if err := yaml.Unmarshal(data, &config); err != nil {
        return nil, err
    }

    return &config, nil
}

func validateConfig(config *AppConfig) error {
    if config.Name == "" {
        return errors.New("name required")
    }
    if config.Image == "" {
        return errors.New("image required")
    }
    return nil
}

func buildImage(ctx context.Context, config *AppConfig) error {
    cmd := exec.CommandContext(ctx, "buildah", "bud", "-t", config.Image, ".")
    return cmd.Run()
}

// ... etc
```

Now each function:

- Does one thing
- Can be tested in isolation
- Can be changed independently
- Has clear inputs/outputs

---

## CLI Orchestrator Pattern

Command-line tools should separate orchestration from execution:

```go
// main.go - entry point
func main() {
    if err := rootCmd.Execute(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}

// cmd/deploy.go - orchestration
var deployCmd = &cobra.Command{
    Use:   "deploy",
    Short: "Deploy application to Kubernetes",
    RunE: func(cmd *cobra.Command, args []string) error {
        // Parse flags
        configPath, _ := cmd.Flags().GetString("config")
        namespace, _ := cmd.Flags().GetString("namespace")

        // Build orchestrator
        orchestrator := deploy.NewOrchestrator(deploy.Config{
            ConfigPath: configPath,
            Namespace:  namespace,
        })

        // Execute
        return orchestrator.Run(cmd.Context())
    },
}

// internal/deploy/orchestrator.go - coordination
type Orchestrator struct {
    config    Config
    parser    *ConfigParser
    builder   *ImageBuilder
    deployer  *K8sDeployer
}

func (o *Orchestrator) Run(ctx context.Context) error {
    // Parse
    appConfig, err := o.parser.Parse(o.config.ConfigPath)
    if err != nil {
        return err
    }

    // Build
    if err := o.builder.Build(ctx, appConfig); err != nil {
        return err
    }

    // Deploy
    return o.deployer.Deploy(ctx, appConfig)
}

// internal/deploy/parser.go - execution
type ConfigParser struct{}

func (p *ConfigParser) Parse(path string) (*AppConfig, error) {
    // Implementation
}

// internal/deploy/builder.go - execution
type ImageBuilder struct{}

func (b *ImageBuilder) Build(ctx context.Context, config *AppConfig) error {
    // Implementation
}
```

Layers:

1. **Entry point** - `main.go` just calls cobra
2. **CLI layer** - Parses flags, no business logic
3. **Orchestrator** - Coordinates execution
4. **Executors** - Do actual work

---

## Next Steps

- **[Implementation Techniques](implementation.md)** - Testing, interfaces, dependency injection, error handling
- **[Usage Guide](guide.md)** - When to apply, common mistakes, real-world examples

---

*Each component does one thing well. Changes are isolated. Tests run in milliseconds. The system is maintainable.*
