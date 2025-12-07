# Integration Testing

Test against real Kubernetes API servers with envtest.

!!! tip "Real API, Fast Tests"
    envtest provides a real Kubernetes API server without the overhead of a full cluster. Catch API contract issues that unit tests miss.

---

## Setup with envtest

Use `sigs.k8s.io/controller-runtime/pkg/envtest` for testing against a real API server:

```go
//go:build integration

package k8s

import (
    "context"
    "os"
    "testing"

    "k8s.io/client-go/kubernetes"
    "sigs.k8s.io/controller-runtime/pkg/envtest"
)

var (
    testEnv   *envtest.Environment
    clientset *kubernetes.Clientset
)

func TestMain(m *testing.M) {
    testEnv = &envtest.Environment{}

    cfg, err := testEnv.Start()
    if err != nil {
        panic(err)
    }

    clientset, err = kubernetes.NewForConfig(cfg)
    if err != nil {
        panic(err)
    }

    code := m.Run()

    if err := testEnv.Stop(); err != nil {
        panic(err)
    }

    os.Exit(code)
}

func TestListDeployments(t *testing.T) {
    ctx := context.Background()

    // Create test deployment
    deployment := createTestDeployment("test-app")
    _, err := clientset.AppsV1().Deployments("default").Create(ctx, deployment, metav1.CreateOptions{})
    if err != nil {
        t.Fatalf("failed to create deployment: %v", err)
    }

    // Test listing
    client := &Client{Clientset: clientset, Namespace: "default"}
    deployments, err := client.ListDeployments(ctx)
    if err != nil {
        t.Fatalf("failed to list deployments: %v", err)
    }

    if len(deployments) != 1 {
        t.Errorf("expected 1 deployment, got %d", len(deployments))
    }
}
```

---

## Build Tags

Run integration tests with build tags:

```bash
# Run only unit tests (default)
go test -v ./...

# Run integration tests
go test -v -tags=integration ./pkg/...

# Run all tests
go test -v -tags=integration ./...
```

---

## Test Fixtures

Create reusable test helpers:

```go
//go:build integration

package k8s

import (
    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

func createTestDeployment(name string) *appsv1.Deployment {
    replicas := int32(1)
    return &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      name,
            Namespace: "default",
            Labels: map[string]string{
                "app": name,
            },
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: map[string]string{
                    "app": name,
                },
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: map[string]string{
                        "app": name,
                    },
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{
                        {
                            Name:  "main",
                            Image: "nginx:latest",
                        },
                    },
                },
            },
        },
    }
}

func createTestNamespace(name string) *corev1.Namespace {
    return &corev1.Namespace{
        ObjectMeta: metav1.ObjectMeta{
            Name: name,
        },
    }
}
```

---

## Cleanup Patterns

Always clean up test resources:

```go
func TestWithCleanup(t *testing.T) {
    ctx := context.Background()

    // Create namespace for test isolation
    ns := createTestNamespace("test-" + randomSuffix())
    _, err := clientset.CoreV1().Namespaces().Create(ctx, ns, metav1.CreateOptions{})
    if err != nil {
        t.Fatalf("failed to create namespace: %v", err)
    }

    // Ensure cleanup
    t.Cleanup(func() {
        clientset.CoreV1().Namespaces().Delete(ctx, ns.Name, metav1.DeleteOptions{})
    })

    // Run tests in isolated namespace
    // ...
}
```

---

## Testing with kind

For more realistic integration tests, use kind:

```go
//go:build integration

package e2e

import (
    "os/exec"
    "testing"
)

func TestMain(m *testing.M) {
    // Create kind cluster
    cmd := exec.Command("kind", "create", "cluster", "--name", "test-cluster")
    if err := cmd.Run(); err != nil {
        panic(err)
    }

    code := m.Run()

    // Delete kind cluster
    cmd = exec.Command("kind", "delete", "cluster", "--name", "test-cluster")
    cmd.Run()

    os.Exit(code)
}
```

---

*Integration tests catch API contract issues that unit tests miss.*
