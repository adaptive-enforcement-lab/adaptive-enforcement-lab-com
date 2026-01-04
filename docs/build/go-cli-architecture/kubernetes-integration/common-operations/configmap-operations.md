---
title: ConfigMap Operations
description: >-
  Store CLI state in Kubernetes ConfigMaps with get-or-create pattern for idempotent operations. Check IsNotFound before creating resources safely.
---
# ConfigMap Operations

Store and retrieve configuration data in Kubernetes.

!!! tip "Get-or-Create Pattern"
    Check `apierrors.IsNotFound(err)` before creating resources. This makes operations idempotent and safe to re-run.

---

## Get or Create Pattern

The get-or-create pattern is essential for idempotent CLI operations. Check if a resource exists before creating it:

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
```

---

## Update ConfigMap

!!! warning "Check IsNotFound First"
    Always check `apierrors.IsNotFound(err)` before attempting to create a resource. Other errors (network issues, permission denied) should be returned immediately.

```go
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

## Cache Storage Pattern

Use ConfigMaps to store CLI state between runs:

```go
const cacheConfigMapName = "myctl-cache"

// SaveCache stores cache data in a ConfigMap
func (c *Client) SaveCache(ctx context.Context, cacheData map[string]string) error {
    return c.UpdateConfigMap(ctx, cacheConfigMapName, cacheData)
}

// LoadCache retrieves cache data from a ConfigMap
func (c *Client) LoadCache(ctx context.Context) (map[string]string, error) {
    cm, err := c.GetOrCreateConfigMap(ctx, cacheConfigMapName)
    if err != nil {
        return nil, err
    }
    return cm.Data, nil
}
```

---

## Best Practices

| Practice | Description |
| ---------- | ------------- |
| **Idempotent operations** | Get-or-create for safe re-runs |
| **Check error types** | Use `apierrors.IsNotFound()` before creating |
| **Initialize Data field** | Always initialize maps: `Data: make(map[string]string)` |
| **Use labels** | Add labels for CLI ownership: `app.kubernetes.io/managed-by: myctl` |
| **Limit data size** | ConfigMaps have a 1MB limit |

---

*Use ConfigMaps for persistent CLI state that survives pod restarts.*
