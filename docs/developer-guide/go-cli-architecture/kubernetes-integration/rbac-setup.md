# RBAC Setup

Configure service accounts and permissions for your CLI.

---

## Service Account Setup

Create a service account with appropriate permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myctl
  namespace: myctl-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: myctl-role
rules:
  # Read deployments across namespaces
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch"]

  # Restart deployments (patch for rollout restart)
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["patch"]

  # Read pods for status checks
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]

  # ConfigMaps for cache storage
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: myctl-binding
subjects:
  - kind: ServiceAccount
    name: myctl
    namespace: myctl-system
roleRef:
  kind: ClusterRole
  name: myctl-role
  apiGroup: rbac.authorization.k8s.io
```

---

## Namespace-Scoped Permissions

For namespace-scoped permissions, use `Role` and `RoleBinding` instead:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: myctl-role
  namespace: production
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: myctl-binding
  namespace: production
subjects:
  - kind: ServiceAccount
    name: myctl
    namespace: myctl-system
roleRef:
  kind: Role
  name: myctl-role
  apiGroup: rbac.authorization.k8s.io
```

---

## Permission Patterns

| Operation | API Group | Resource | Verbs |
|-----------|-----------|----------|-------|
| List deployments | `apps` | `deployments` | `get`, `list`, `watch` |
| Rollout restart | `apps` | `deployments` | `patch` |
| Read pod status | `""` (core) | `pods` | `get`, `list` |
| Manage ConfigMaps | `""` (core) | `configmaps` | `get`, `list`, `create`, `update`, `patch` |
| Read secrets | `""` (core) | `secrets` | `get`, `list` |

---

## Minimal RBAC Principle

!!! danger "Principle of Least Privilege"

    Never use wildcard permissions (`*`). Security teams will reject your deployment, and over-permissioned service accounts are a breach waiting to happen.

Only request permissions your CLI actually needs:

```yaml
# Bad: Too broad
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]

# Good: Specific permissions
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "patch"]
```

---

## Debugging RBAC Issues

Check if your service account has the required permissions:

```bash
# Can I list deployments?
kubectl auth can-i list deployments --as=system:serviceaccount:myctl-system:myctl

# Can I patch deployments in production namespace?
kubectl auth can-i patch deployments -n production \
    --as=system:serviceaccount:myctl-system:myctl
```

---

*Minimal RBAC: only grant what your CLI needs to function.*
