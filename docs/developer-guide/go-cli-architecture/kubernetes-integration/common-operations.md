# Common Operations

Implement common Kubernetes operations in your CLI.

!!! tip "API Idioms"
    Use the Kubernetes API idiomatically: label selectors for filtering, strategic merge patches for updates, and proper error handling for all operations.

---

## List Deployments

```go
package k8s

import (
    "context"

    appsv1 "k8s.io/api/apps/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// ListDeployments returns all deployments in the configured namespace
func (c *Client) ListDeployments(ctx context.Context) ([]appsv1.Deployment, error) {
    list, err := c.Clientset.AppsV1().Deployments(c.Namespace).List(ctx, metav1.ListOptions{})
    if err != nil {
        return nil, err
    }
    return list.Items, nil
}

// ListDeploymentsWithLabel returns deployments matching a label selector
func (c *Client) ListDeploymentsWithLabel(ctx context.Context, labelSelector string) ([]appsv1.Deployment, error) {
    list, err := c.Clientset.AppsV1().Deployments(c.Namespace).List(ctx, metav1.ListOptions{
        LabelSelector: labelSelector,
    })
    if err != nil {
        return nil, err
    }
    return list.Items, nil
}
```

---

## Rollout Restart

Trigger a rolling restart by patching the deployment's pod template annotation:

```go
package k8s

import (
    "context"
    "fmt"
    "time"

    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/types"
)

// RestartDeployment triggers a rollout restart
func (c *Client) RestartDeployment(ctx context.Context, name string) error {
    // Patch the deployment with a new annotation to trigger restart
    patch := fmt.Sprintf(`{"spec":{"template":{"metadata":{"annotations":{"kubectl.kubernetes.io/restartedAt":"%s"}}}}}`,
        time.Now().Format(time.RFC3339))

    _, err := c.Clientset.AppsV1().Deployments(c.Namespace).Patch(
        ctx,
        name,
        types.StrategicMergePatchType,
        []byte(patch),
        metav1.PatchOptions{},
    )
    return err
}
```

---

## ConfigMap Operations

Store and retrieve data from ConfigMaps:

```go
package k8s

import (
    "context"
    "fmt"

    corev1 "k8s.io/api/core/v1"
    apierrors "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// GetOrCreateConfigMap retrieves or creates a ConfigMap
func (c *Client) GetOrCreateConfigMap(ctx context.Context, name string) (*corev1.ConfigMap, error) {
    cm, err := c.Clientset.CoreV1().ConfigMaps(c.Namespace).Get(ctx, name, metav1.GetOptions{})
    if err == nil {
        return cm, nil
    }

    if !apierrors.IsNotFound(err) {
        return nil, fmt.Errorf("failed to get configmap: %w", err)
    }

    // Create new ConfigMap
    cm = &corev1.ConfigMap{
        ObjectMeta: metav1.ObjectMeta{
            Name:      name,
            Namespace: c.Namespace,
        },
        Data: make(map[string]string),
    }

    return c.Clientset.CoreV1().ConfigMaps(c.Namespace).Create(ctx, cm, metav1.CreateOptions{})
}

// UpdateConfigMap updates data in a ConfigMap
func (c *Client) UpdateConfigMap(ctx context.Context, name string, data map[string]string) error {
    cm, err := c.GetOrCreateConfigMap(ctx, name)
    if err != nil {
        return err
    }

    cm.Data = data
    _, err = c.Clientset.CoreV1().ConfigMaps(c.Namespace).Update(ctx, cm, metav1.UpdateOptions{})
    return err
}
```

---

## Watch Resources

Watch for changes to resources:

```go
package k8s

import (
    "context"

    appsv1 "k8s.io/api/apps/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/watch"
)

// WatchDeployments watches for deployment changes
func (c *Client) WatchDeployments(ctx context.Context) (watch.Interface, error) {
    return c.Clientset.AppsV1().Deployments(c.Namespace).Watch(ctx, metav1.ListOptions{})
}

// Example usage
func watchExample(ctx context.Context, client *Client) error {
    watcher, err := client.WatchDeployments(ctx)
    if err != nil {
        return err
    }
    defer watcher.Stop()

    for event := range watcher.ResultChan() {
        deployment := event.Object.(*appsv1.Deployment)
        switch event.Type {
        case watch.Added:
            fmt.Printf("Deployment added: %s\n", deployment.Name)
        case watch.Modified:
            fmt.Printf("Deployment modified: %s\n", deployment.Name)
        case watch.Deleted:
            fmt.Printf("Deployment deleted: %s\n", deployment.Name)
        }
    }
    return nil
}
```

---

## Best Practices

| Practice | Description |
|----------|-------------|
| **Use label selectors** | Filter resources server-side, not client-side |
| **Prefer patches over updates** | Patches are safer for concurrent modifications |
| **Use strategic merge patches** | Kubernetes-native patch format for resources |
| **Handle not found errors** | Check `apierrors.IsNotFound(err)` before creating |
| **Respect resource versions** | Use optimistic concurrency for updates |

---

*Use the Kubernetes API idiomatically: label selectors, patches, and proper error handling.*
