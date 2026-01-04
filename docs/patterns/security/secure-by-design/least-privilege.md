---
title: Least Privilege
description: >-
  Least privilege pattern for Kubernetes. Scoped ServiceAccounts, minimal RBAC permissions, and resource-level access control to limit blast radius.
tags:
  - security
  - kubernetes
  - rbac
  - least-privilege
---
# Least Privilege

Least privilege grants only the minimum permissions required for a task. Nothing more.

## Core Principle

Every workload, user, and service should have the smallest set of permissions needed to function.

**Key Properties**:

- Explicit permission grants (no wildcards)
- Resource-level granularity
- Scoped to specific namespaces
- Time-bound where possible
- Auditable and traceable

## ServiceAccount Best Practices

Every pod runs with a ServiceAccount. Default is too permissive.

### Scoped ServiceAccount Pattern

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-service
  namespace: production
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: backend-pod
  namespace: production
spec:
  serviceAccountName: backend-service
  automountServiceAccountToken: false
  containers:
  - name: app
    image: backend:1.0
```

**What This Does**:

- Creates dedicated ServiceAccount per workload
- Disables automatic token mounting
- Prevents accidental API access
- Reduces attack surface

### When to Mount ServiceAccount Tokens

Only mount when workload needs Kubernetes API access:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: controller-pod
  namespace: production
spec:
  serviceAccountName: deployment-controller
  automountServiceAccountToken: true
  containers:
  - name: controller
    image: controller:1.0
    env:
    - name: KUBERNETES_SERVICE_HOST
      value: "kubernetes.default.svc"
```

**Rule of Thumb**:

- Most workloads: `automountServiceAccountToken: false`
- Controllers/operators: `automountServiceAccountToken: true`
- If you don't use kubectl/client-go: disable token mounting

## RBAC Patterns

### Minimal Role Pattern

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: deployment-reader
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: deployment-reader-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: backend-service
  namespace: production
roleRef:
  kind: Role
  name: deployment-reader
  apiGroup: rbac.authorization.k8s.io
```

**What This Grants**:

- Read-only access to deployments
- Scoped to production namespace only
- No create, update, or delete permissions
- No access to other resource types

### Resource-Specific Permissions

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-manager
  namespace: production
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config", "feature-flags"]
  verbs: ["get", "update"]
```

**Key Detail**: `resourceNames` restricts to specific ConfigMaps only.

**What This Prevents**:

- Access to other ConfigMaps in namespace
- Creating new ConfigMaps
- Deleting existing ConfigMaps
- Listing all ConfigMaps

!!! warning "Wildcards Are Cluster-Admin"
    Using `*` in apiGroups, resources, or verbs is effectively cluster-admin. If you need wildcard permissions, you're doing it wrong. Enumerate specific resources.

### Common RBAC Anti-Patterns

#### Anti-Pattern 1: Wildcard Permissions

```yaml
# DON'T DO THIS
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
```

**Why This Is Dangerous**:

- Grants cluster-admin equivalent permissions
- No audit trail of what was actually needed
- Violates least privilege principle

#### Anti-Pattern 2: Cluster-Level Permissions for Workloads

```yaml
# DON'T DO THIS
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: app-cluster-admin
subjects:
- kind: ServiceAccount
  name: app-service
  namespace: production
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

**Why This Is Dangerous**:

- Application can access all namespaces
- Full control over cluster resources
- No namespace isolation

**Correct Pattern**:

```yaml
# DO THIS INSTEAD
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding  # Note: RoleBinding not ClusterRoleBinding
metadata:
  name: app-reader
  namespace: production
subjects:
- kind: ServiceAccount
  name: app-service
  namespace: production
roleRef:
  kind: Role  # Note: Role not ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

## Permission Granularity

### Read vs. Write Permissions

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: production
rules:
# Read-only access to secrets
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["database-credentials"]
  verbs: ["get"]
```

**Verb Hierarchy** (from least to most privilege):

1. `get` - Read single resource
2. `list` - Read multiple resources
3. `watch` - Stream resource changes
4. `create` - Create new resources
5. `update` - Modify existing resources
6. `patch` - Partial updates
7. `delete` - Remove resources
8. `deletecollection` - Remove multiple resources

### Subresource Permissions

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-logger
  namespace: production
rules:
# Access to pod logs only (not pod spec)
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
# No access to pods themselves
```

## Cross-Namespace Isolation

### Preventing Cross-Namespace Access

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: namespace-scoped
  namespace: production
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list"]
```

**What This Enforces**:

- ServiceAccount in production can ONLY access production namespace
- Even if deployment exists in staging, this Role cannot see it
- Namespace boundary is hard security boundary

### ClusterRole for Cross-Namespace (Use Sparingly)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-viewer
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding  # Note: RoleBinding limits ClusterRole to namespace
metadata:
  name: node-viewer-binding
  namespace: production
subjects:
- kind: ServiceAccount
  name: monitoring-service
  namespace: production
roleRef:
  kind: ClusterRole
  name: node-viewer
  apiGroup: rbac.authorization.k8s.io
```

**Pattern**: ClusterRole with RoleBinding scopes cluster-level permissions to namespace.

## Real-World Examples

See [integration.md](integration.md) for complete RBAC examples including CI/CD pipelines, monitoring services, and secret management patterns.

## Permission Audit Checklist

Before deploying RBAC rules, verify:

- [ ] ServiceAccount is scoped to single purpose
- [ ] No wildcard (`*`) in apiGroups, resources, or verbs
- [ ] No cluster-admin role bindings for workloads
- [ ] resourceNames specified for sensitive resources
- [ ] Verbs are minimal (prefer `get` over `list`, no `delete` unless required)
- [ ] RoleBinding (not ClusterRoleBinding) unless cross-namespace needed
- [ ] automountServiceAccountToken: false unless API access needed
- [ ] Review permissions every 90 days

## Testing RBAC Permissions

### Using kubectl auth can-i

```bash
# Test as ServiceAccount
kubectl auth can-i get pods \
  --as=system:serviceaccount:production:backend-service \
  --namespace=production

# Test specific resource
kubectl auth can-i delete deployment/app \
  --as=system:serviceaccount:production:cicd-deployer \
  --namespace=production

# Test cross-namespace
kubectl auth can-i get deployments \
  --as=system:serviceaccount:production:backend-service \
  --namespace=staging
```

**Expected Results**:

- Should return `yes` for granted permissions
- Should return `no` for denied permissions
- Use in CI/CD to verify RBAC configuration

## Threat Model

| Threat | Mitigation |
|--------|-----------|
| **Lateral movement** | Namespace-scoped Roles, no cluster-admin bindings |
| **Privilege escalation** | No wildcard verbs, no update on RBAC resources |
| **Secret exposure** | resourceNames on secrets, no list permission |
| **Configuration tampering** | Read-only access where possible, resourceNames |
| **Cross-namespace access** | RoleBinding (not ClusterRoleBinding), explicit namespace scoping |

## References

- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Principle of Least Privilege](https://csrc.nist.gov/glossary/term/least_privilege)
- [Audit RBAC Permissions](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)

---

*Grant minimum required permissions. Review regularly. Audit everything.*
