# Unit Testing

Use fake clients and interface-based design for fast, reliable unit tests.

!!! info "Why Fakes Over Mocks"

    Fakes are simpler to maintain than mocks. They implement the same interface and let you verify behavior through state inspection rather than call verification.

---

## Interface-Based Design

Define interfaces for testability:

```go
// pkg/k8s/interfaces.go
package k8s

import (
    "context"

    appsv1 "k8s.io/api/apps/v1"
)

// DeploymentClient defines operations on deployments
type DeploymentClient interface {
    List(ctx context.Context, namespace string) ([]appsv1.Deployment, error)
    Restart(ctx context.Context, namespace, name string) error
}
```

---

## Fake Implementation

```go
// pkg/k8s/fake_client.go
package k8s

import (
    "context"
    "fmt"

    appsv1 "k8s.io/api/apps/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type FakeDeploymentClient struct {
    Deployments map[string]*appsv1.Deployment
    RestartLog  []string
    ListError   error
    RestartError error
}

func NewFakeDeploymentClient() *FakeDeploymentClient {
    return &FakeDeploymentClient{
        Deployments: make(map[string]*appsv1.Deployment),
        RestartLog:  []string{},
    }
}

func (f *FakeDeploymentClient) AddDeployment(namespace, name string, labels map[string]string) {
    key := fmt.Sprintf("%s/%s", namespace, name)
    f.Deployments[key] = &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      name,
            Namespace: namespace,
            Labels:    labels,
        },
    }
}

func (f *FakeDeploymentClient) List(ctx context.Context, namespace string) ([]appsv1.Deployment, error) {
    if f.ListError != nil {
        return nil, f.ListError
    }
    // Return matching deployments
    var result []appsv1.Deployment
    for _, d := range f.Deployments {
        if d.Namespace == namespace {
            result = append(result, *d)
        }
    }
    return result, nil
}

func (f *FakeDeploymentClient) Restart(ctx context.Context, namespace, name string) error {
    if f.RestartError != nil {
        return f.RestartError
    }
    f.RestartLog = append(f.RestartLog, fmt.Sprintf("%s/%s", namespace, name))
    return nil
}
```

---

## Table-Driven Tests

```go
func TestSelectDeployments(t *testing.T) {
    tests := []struct {
        name      string
        setup     func(*k8s.FakeDeploymentClient)
        wantCount int
        wantErr   bool
    }{
        {
            name: "selects matching deployments",
            setup: func(fc *k8s.FakeDeploymentClient) {
                fc.AddDeployment("default", "app-1", map[string]string{"app": "myapp"})
                fc.AddDeployment("default", "app-2", map[string]string{"app": "myapp"})
            },
            wantCount: 2,
        },
        {
            name: "returns empty for no matches",
            setup: func(fc *k8s.FakeDeploymentClient) {
                fc.AddDeployment("other", "app-1", map[string]string{"app": "myapp"})
            },
            wantCount: 0,
        },
        {
            name: "handles list error",
            setup: func(fc *k8s.FakeDeploymentClient) {
                fc.ListError = fmt.Errorf("connection refused")
            },
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            fc := k8s.NewFakeDeploymentClient()
            tt.setup(fc)

            got, err := selectDeployments(context.Background(), fc, "default")

            if (err != nil) != tt.wantErr {
                t.Errorf("error = %v, wantErr %v", err, tt.wantErr)
            }
            if len(got) != tt.wantCount {
                t.Errorf("got %d deployments, want %d", len(got), tt.wantCount)
            }
        })
    }
}
```

---

## Testing Commands

```go
package cmd

import (
    "bytes"
    "strings"
    "testing"

    "github.com/spf13/cobra"
)

func executeCommand(root *cobra.Command, args ...string) (string, error) {
    buf := new(bytes.Buffer)
    root.SetOut(buf)
    root.SetErr(buf)
    root.SetArgs(args)
    err := root.Execute()
    return buf.String(), err
}

func TestCheckCommand(t *testing.T) {
    output, err := executeCommand(rootCmd, "check", "--json")
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }
    if !strings.Contains(output, `"valid"`) {
        t.Errorf("expected JSON output with valid field")
    }
}

func TestVersionCommand(t *testing.T) {
    output, err := executeCommand(rootCmd, "version")
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }
    if !strings.Contains(output, "Version:") {
        t.Errorf("expected version output, got: %s", output)
    }
}
```

---

## Parallel Tests

```go
func TestDeploymentOperations(t *testing.T) {
    t.Run("list", func(t *testing.T) {
        t.Parallel()
        // test list operation
    })

    t.Run("restart", func(t *testing.T) {
        t.Parallel()
        // test restart operation
    })
}
```

---

*Fast unit tests with fakes catch logic bugs early.*
