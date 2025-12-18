---
description: >-
  Query Kubernetes resources with server-side label selectors for efficient filtering. Reduce network traffic and memory usage in CLI operations.
---

# List Resources

Query Kubernetes resources with label selectors.

!!! tip "Server-Side Filtering"
    Always filter resources server-side using label selectors. This reduces network traffic and memory usage compared to client-side filtering.

---

## List All Deployments

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
```

---

## Filter with Label Selectors

!!! tip "Server-Side Filtering"
    Always filter resources server-side using label selectors. This reduces network traffic and memory usage compared to client-side filtering.

```go
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

## Label Selector Examples

| Selector | Description |
| ---------- | ------------- |
| `app=nginx` | Exact match |
| `app!=nginx` | Not equal |
| `app in (nginx,haproxy)` | Set membership |
| `app notin (nginx,haproxy)` | Set exclusion |
| `app` | Key exists |
| `!app` | Key does not exist |
| `app=nginx,env=prod` | Multiple conditions (AND) |

---

## Command Usage

```go
func runSelect(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    label, _ := cmd.Flags().GetString("label")

    var deployments []appsv1.Deployment
    var err error

    if label != "" {
        deployments, err = client.ListDeploymentsWithLabel(ctx, label)
    } else {
        deployments, err = client.ListDeployments(ctx)
    }

    if err != nil {
        return fmt.Errorf("failed to list deployments: %w", err)
    }

    for _, d := range deployments {
        fmt.Printf("%s (%d/%d ready)\n",
            d.Name,
            d.Status.ReadyReplicas,
            d.Status.Replicas)
    }

    return nil
}
```

---

*Filter resources server-side with label selectors for efficiency.*
