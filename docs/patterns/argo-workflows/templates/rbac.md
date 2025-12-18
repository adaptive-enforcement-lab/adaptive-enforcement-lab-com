---
description: >-
  Apply least privilege to workflows with ServiceAccount RBAC. Restrict verbs, resources, and names to minimize blast radius and prevent security escalation.
---

# RBAC Configuration

Workflows execute with the permissions of their ServiceAccount. The principle of least privilege applies: grant only the verbs and resources the workflow actually needs. Overly permissive RBAC creates security risks; overly restrictive RBAC causes runtime failures.

---

## Why RBAC Matters

A workflow that can list all secrets in the cluster can exfiltrate credentials. A workflow that can patch deployments in any namespace can modify production services. A workflow that can create pods can mine cryptocurrency.

Most workflows need narrow permissions: read one ConfigMap, restart specific deployments, write to one PVC. But the default ServiceAccount often has no permissions, causing workflows to fail with cryptic RBAC errors. The temptation is to grant broad permissions to make things work quickly. Don't.

Take the time to figure out exactly what permissions your workflow needs. Grant those and nothing more. When the workflow's requirements change, update the RBAC to match.

---

## Basic RBAC Setup

A minimal RBAC configuration has three parts: ServiceAccount, Role/ClusterRole, and RoleBinding/ClusterRoleBinding.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployment-restarter
  namespace: argo-workflows
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deployment-restarter
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "patch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
    resourceNames: ["deployment-image-cache"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: deployment-restarter
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deployment-restarter
subjects:
  - kind: ServiceAccount
    name: deployment-restarter
    namespace: argo-workflows
```

The ServiceAccount defines the identity. The ClusterRole defines what operations are allowed. The ClusterRoleBinding connects them.

---

## Role vs ClusterRole

The choice between Role and ClusterRole depends on scope:

| Type | Scope | Use Case |
| ------ | ------- | ---------- |
| Role + RoleBinding | Single namespace | Workflow operates in one namespace |
| ClusterRole + RoleBinding | Single namespace | Reusable permissions, namespace-specific binding |
| ClusterRole + ClusterRoleBinding | All namespaces | Workflow operates across namespaces |

**Most workflows need ClusterRole + ClusterRoleBinding** because they operate on resources in multiple namespaces. A deployment restart workflow might need to restart deployments in `production`, `staging`, and `development`.

Use namespace-scoped Role + RoleBinding when the workflow truly operates in only one namespace and you want to limit blast radius.

---

## Restricting by Resource Name

The `resourceNames` field limits access to specific named resources:

```yaml
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
    resourceNames: ["deployment-image-cache"]
```

This workflow can only read the `deployment-image-cache` ConfigMap and no other ConfigMaps. If compromised, it can't access other configuration or secrets stored in ConfigMaps.

**Use `resourceNames` whenever possible.** It significantly reduces blast radius.

---

## Common Permission Patterns

**Deployment management:**

```yaml
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "patch"]
  - apiGroups: ["apps"]
    resources: ["deployments/scale"]
    verbs: ["patch"]
```

**Pod inspection:**

```yaml
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log"]
    verbs: ["get", "list"]
```

**Secret access (be careful):**

```yaml
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
    resourceNames: ["specific-secret-name"]  # Always restrict by name
```

**Creating child workflows:**

```yaml
rules:
  - apiGroups: ["argoproj.io"]
    resources: ["workflows"]
    verbs: ["create", "get", "watch"]
```

---

## Debugging RBAC Issues

When workflows fail with permission errors, use `kubectl auth can-i` to test what the ServiceAccount can actually do:

```bash
kubectl auth can-i patch deployments \
  --as=system:serviceaccount:argo-workflows:deployment-restarter \
  -n target-namespace
```

The `--as` flag impersonates the ServiceAccount. The response tells you whether that specific operation is allowed.

**Common mistakes:**

| Symptom | Cause | Fix |
| --------- | ------- | ----- |
| `forbidden: User "system:serviceaccount:..."` | Missing verb | Add the verb to rules |
| `cannot get resource "deployments"` | Missing resource | Add the resource to rules |
| `not found` | Wrong namespace | Check namespace in subjects |
| Works manually, fails in workflow | Wrong ServiceAccount | Check workflow's `serviceAccountName` |

---

## ServiceAccount in WorkflowTemplates

Reference the ServiceAccount in your WorkflowTemplate:

```yaml
spec:
  serviceAccountName: deployment-restarter
  templates:
    - name: restart
      serviceAccountName: deployment-restarter  # Can also specify per-template
```

The `serviceAccountName` at the spec level applies to all templates. Per-template overrides allow different templates to run with different permissions. This is useful for multi-stage workflows where some stages need broader access than others.

---

## Audit and Review

RBAC configurations drift over time. Workflows gain permissions for debugging and keep them. New features add permissions that aren't cleaned up when removed.

Periodically review your workflow RBAC:

1. List all ServiceAccounts in your workflow namespace
2. Check what ClusterRoleBindings reference them
3. Review the ClusterRole rules
4. Ask: "Does this workflow actually need all these permissions?"

Remove permissions that aren't needed. Tighten `resourceNames` where possible. The goal is to minimize blast radius if any workflow is compromised.

---

!!! warning "Avoid ClusterRoleBindings When Possible"
    ClusterRoleBindings grant permissions across all namespaces. Prefer namespace-scoped RoleBindings unless you specifically need cluster-wide access.

---

## Related

- [Basic Structure](basic-structure.md) - WorkflowTemplate anatomy
- [Volume Patterns](volume-patterns.md) - Restricting volume access
- [Workflow Composition](../composition/index.md) - RBAC for parent/child workflows
