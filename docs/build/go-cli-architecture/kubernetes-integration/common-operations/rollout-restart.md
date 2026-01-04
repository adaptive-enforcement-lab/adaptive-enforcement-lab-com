---
title: Rollout Restart
description: >-
  Trigger zero-downtime rolling restarts with annotation patches. Strategic merge patches modify pod templates safely without full object replacement.
---
# Rollout Restart

Trigger rolling restarts without downtime.

!!! info "Annotation Patch Trick"
    Kubernetes has no native restart. Patch the pod template with a `restartedAt` annotation to trigger a rolling update.

---

## How It Works

Kubernetes doesn't have a native "restart" operation. Instead, we trigger a rollout by patching the deployment's pod template with a new annotation. This causes the ReplicaSet controller to create new pods with the updated template.

```mermaid
graph LR
    Patch[Patch Annotation] --> NewRS[New ReplicaSet]
    NewRS --> ScaleUp[Scale Up New Pods]
    ScaleUp --> ScaleDown[Scale Down Old Pods]
    ScaleDown --> Done[Restart Complete]

    %% Ghostty Hardcore Theme
    style Patch fill:#fd971e,color:#1b1d1e
    style NewRS fill:#65d9ef,color:#1b1d1e
    style ScaleUp fill:#65d9ef,color:#1b1d1e
    style ScaleDown fill:#65d9ef,color:#1b1d1e
    style Done fill:#a7e22e,color:#1b1d1e

```

---

## Implementation

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

## Why Patches?

!!! info "Patches vs Updates"
    Patches are safer than full updates for concurrent modifications. A strategic merge patch only modifies the fields you specify, while an update replaces the entire object and can conflict with other controllers.

---

## Batch Restart

```go
// RestartDeployments restarts multiple deployments
func (c *Client) RestartDeployments(ctx context.Context, names []string) error {
    for _, name := range names {
        if err := c.RestartDeployment(ctx, name); err != nil {
            return fmt.Errorf("failed to restart %s: %w", name, err)
        }
    }
    return nil
}
```

---

## Command Usage

```go
func runRestart(cmd *cobra.Command, args []string) error {
    ctx := cmd.Context()

    if len(args) == 0 {
        return fmt.Errorf("deployment name required")
    }

    for _, name := range args {
        if err := client.RestartDeployment(ctx, name); err != nil {
            return fmt.Errorf("failed to restart %s: %w", name, err)
        }
        fmt.Printf("Restarted deployment: %s\n", name)
    }

    return nil
}
```

---

*Use annotation patches to trigger zero-downtime rolling restarts.*
