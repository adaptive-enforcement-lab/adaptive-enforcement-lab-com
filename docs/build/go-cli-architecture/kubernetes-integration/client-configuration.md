---
description: >-
  Handle both in-cluster and out-of-cluster Kubernetes configurations automatically. Detect kubeconfig, KUBECONFIG env var, or service account tokens.
---

# Client Configuration

Handle both in-cluster and out-of-cluster Kubernetes configurations.

!!! warning "Always Support Both Environments"

    Your CLI must work on developer laptops (kubeconfig) AND inside pods (in-cluster). Test both paths or users will hit runtime failures.

---

## Automatic Configuration Detection

```go
package k8s

import (
    "fmt"
    "os"
    "path/filepath"

    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
    "k8s.io/client-go/tools/clientcmd"
)

// Client wraps the Kubernetes clientset with configuration
type Client struct {
    Clientset *kubernetes.Clientset
    Config    *rest.Config
    Namespace string
}

// NewClient creates a Kubernetes client with automatic config detection
func NewClient(kubeconfig, namespace string) (*Client, error) {
    config, err := getConfig(kubeconfig)
    if err != nil {
        return nil, fmt.Errorf("failed to get kubernetes config: %w", err)
    }

    clientset, err := kubernetes.NewForConfig(config)
    if err != nil {
        return nil, fmt.Errorf("failed to create kubernetes client: %w", err)
    }

    // Resolve namespace
    ns := resolveNamespace(namespace)

    return &Client{
        Clientset: clientset,
        Config:    config,
        Namespace: ns,
    }, nil
}

func getConfig(kubeconfig string) (*rest.Config, error) {
    // Explicit kubeconfig path
    if kubeconfig != "" {
        return clientcmd.BuildConfigFromFlags("", kubeconfig)
    }

    // In-cluster config (running inside a pod)
    if _, err := os.Stat("/var/run/secrets/kubernetes.io/serviceaccount/token"); err == nil {
        return rest.InClusterConfig()
    }

    // Default kubeconfig from environment or home directory
    if kc := os.Getenv("KUBECONFIG"); kc != "" {
        return clientcmd.BuildConfigFromFlags("", kc)
    }

    home, err := os.UserHomeDir()
    if err != nil {
        return nil, err
    }

    return clientcmd.BuildConfigFromFlags("", filepath.Join(home, ".kube", "config"))
}

func resolveNamespace(namespace string) string {
    if namespace != "" {
        return namespace
    }

    // Read from in-cluster namespace file
    if ns, err := os.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace"); err == nil {
        return string(ns)
    }

    return "default"
}
```

---

## Context and Timeout Handling

```go
package cmd

import (
    "context"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/spf13/cobra"
)

var timeout time.Duration

func init() {
    rootCmd.PersistentFlags().DurationVar(&timeout, "timeout", 30*time.Second, "Operation timeout")
}

func runWithContext(cmd *cobra.Command, fn func(ctx context.Context) error) error {
    // Create context with timeout
    ctx, cancel := context.WithTimeout(context.Background(), timeout)
    defer cancel()

    // Handle interrupt signals
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, os.Interrupt, syscall.SIGTERM)

    errCh := make(chan error, 1)
    go func() {
        errCh <- fn(ctx)
    }()

    select {
    case err := <-errCh:
        return err
    case <-sigCh:
        cancel()
        return context.Canceled
    }
}

// Usage in a command
var checkCmd = &cobra.Command{
    Use:   "check",
    Short: "Check cache status",
    RunE: func(cmd *cobra.Command, args []string) error {
        return runWithContext(cmd, func(ctx context.Context) error {
            // Your operation here
            return performCheck(ctx)
        })
    },
}
```

---

## Error Handling

### Kubernetes-Specific Errors

```go
package k8s

import (
    "errors"
    "fmt"

    apierrors "k8s.io/apimachinery/pkg/api/errors"
)

// HandleError provides user-friendly error messages
func HandleError(err error, resource, name string) error {
    if err == nil {
        return nil
    }

    var statusErr *apierrors.StatusError
    if errors.As(err, &statusErr) {
        switch {
        case apierrors.IsNotFound(err):
            return fmt.Errorf("%s '%s' not found", resource, name)
        case apierrors.IsForbidden(err):
            return fmt.Errorf("permission denied: cannot access %s '%s' - check RBAC configuration", resource, name)
        case apierrors.IsUnauthorized(err):
            return fmt.Errorf("unauthorized: check kubeconfig or service account token")
        case apierrors.IsTimeout(err):
            return fmt.Errorf("timeout accessing %s '%s' - check cluster connectivity", resource, name)
        case apierrors.IsServerTimeout(err):
            return fmt.Errorf("server timeout - the API server may be overloaded")
        }
    }

    return fmt.Errorf("failed to access %s '%s': %w", resource, name, err)
}
```

---

*Support all environments: explicit config, KUBECONFIG env var, in-cluster, or ~/.kube/config.*
