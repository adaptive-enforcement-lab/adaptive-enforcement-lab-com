---
description: >-
  OPA Gatekeeper RBAC wildcard prevention template. Block wildcard resources and API groups to enforce least-privilege RBAC.
tags:
  - opa
  - gatekeeper
  - rbac
  - wildcards
  - kubernetes
  - templates
---

# OPA RBAC Wildcard Prevention Template

Prevents Roles and ClusterRoles from using wildcard (`*`) in resources, apiGroups, or verbs. Wildcards grant overly broad permissions and violate least-privilege principles.

!!! warning "Wildcards = Overly Broad Permissions"
    Wildcard permissions grant access to all current and future resources in an API group. Attackers exploit wildcards to access sensitive resources like secrets and cluster configuration.

---

## Template 5: Wildcard Resource Prevention

Blocks creation of Roles and ClusterRoles with wildcard (`*`) in resources, apiGroups, or verbs fields.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblockwildcardrbac
spec:
  crd:
    spec:
      names:
        kind: K8sBlockWildcardRBAC
      validation:
        openAPIV3Schema:
          properties:
            exemptRoles:
              type: array
              items:
                type: string
              description: "Role names exempt from wildcard blocking"
            allowWildcardVerbs:
              type: boolean
              description: "Allow wildcard in verbs field (not recommended)"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockwildcardrbac

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind in ["Role", "ClusterRole"]
          not is_exempt_role
          rule := input.review.object.rules[_]
          apigroup := rule.apiGroups[_]
          apigroup == "*"
          msg := sprintf("%v %v contains wildcard in apiGroups for resources: %v",
            [input.review.kind.kind, input.review.object.metadata.name, rule.resources])
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind in ["Role", "ClusterRole"]
          not is_exempt_role
          rule := input.review.object.rules[_]
          resource := rule.resources[_]
          resource == "*"
          msg := sprintf("%v %v contains wildcard in resources for apiGroups: %v",
            [input.review.kind.kind, input.review.object.metadata.name, rule.apiGroups])
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind in ["Role", "ClusterRole"]
          not is_exempt_role
          not input.parameters.allowWildcardVerbs
          rule := input.review.object.rules[_]
          verb := rule.verbs[_]
          verb == "*"
          msg := sprintf("%v %v contains wildcard in verbs for resources: %v",
            [input.review.kind.kind, input.review.object.metadata.name, rule.resources])
        }

        is_exempt_role {
          role_name := input.review.object.metadata.name
          exempt := input.parameters.exemptRoles[_]
          role_name == exempt
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockWildcardRBAC
metadata:
  name: block-wildcard-rbac
spec:
  enforcementAction: deny  # Use 'dryrun' for testing
  match:
    kinds:
      - apiGroups: ["rbac.authorization.k8s.io"]
        kinds: ["Role", "ClusterRole"]
  parameters:
    allowWildcardVerbs: false
    exemptRoles:
      # System roles that legitimately need wildcards
      - cluster-admin
      - system:controller:namespace-controller
      - system:controller:replicaset-controller
      - system:controller:deployment-controller
      - system:kube-controller-manager
      - system:kube-scheduler
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `allowWildcardVerbs` | `false` | Allow `*` in verbs (not recommended) |
| `exemptRoles` | System controllers | Roles that legitimately need wildcards |
| `enforcementAction` | `deny` | Use `dryrun` to audit existing roles |

### Validation Commands

```bash
# Apply constraint template and constraint
kubectl apply -f opa-block-wildcard-rbac.yaml

# Verify installation
kubectl get constrainttemplates k8sblockwildcardrbac
kubectl get k8sblockwildcardrbac

# Test with wildcard resources (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-wildcard-resources
rules:
  - apiGroups: [""]
    resources: ["*"]  # Wildcard not allowed
    verbs: ["get", "list"]
EOF

# Test with wildcard apiGroups (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-wildcard-apigroups
rules:
  - apiGroups: ["*"]  # Wildcard not allowed
    resources: ["pods"]
    verbs: ["get"]
EOF

# Test with explicit resources (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-explicit
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
EOF

# Check violations
kubectl get k8sblockwildcardrbac block-wildcard-rbac -o yaml

# Audit existing wildcard usage
kubectl get clusterroles -o json | jq -r '
  .items[] |
  . as $role |
  .rules[] |
  select(.apiGroups[]? == "*" or .resources[]? == "*" or .verbs[]? == "*") |
  "\($role.metadata.name): apiGroups=\(.apiGroups), resources=\(.resources), verbs=\(.verbs)"
' | sort | uniq
```

### Use Cases

1. **Least Privilege Enforcement**: Force explicit resource permissions
2. **Future-Proofing**: Prevent automatic access to new resources added to API groups
3. **Compliance Requirements**: Demonstrate granular access controls (SOC 2, PCI-DSS)
4. **Attack Surface Reduction**: Limit scope of compromised service accounts
5. **Permission Auditing**: Make RBAC permissions explicit and auditable

---

## Understanding Wildcard Risks

### Wildcard in Resources

```yaml
resources: ["*"]  # Grants access to ALL resources in API group
```

**Risk:** Grants access to pods, services, configmaps, **secrets**, nodes, persistentvolumes, etc. Including secrets exposes credentials, API keys, and certificates.

### Wildcard in API Groups

```yaml
apiGroups: ["*"]  # Grants access to ALL API groups
```

**Risk:** Grants access to current and **future API groups**. New privileged resources become automatically accessible.

### Wildcard in Verbs

```yaml
verbs: ["*"]  # Grants ALL verbs including destructive operations
```

**Risk:** Grants read (get, list), write (create, update, patch), and delete operations. Developer needing read-only access gains delete permissions.

---

## Recommended Alternative Patterns

### Instead of Wildcard Resources

❌ **Bad:**

```yaml
rules:
  - apiGroups: [""]
    resources: ["*"]
    verbs: ["get", "list"]
```

✅ **Good:**

```yaml
rules:
  - apiGroups: [""]
    resources:
      - pods
      - services
      - configmaps
      - endpoints
    verbs: ["get", "list", "watch"]
```

### Instead of Wildcard API Groups

❌ **Bad:**

```yaml
rules:
  - apiGroups: ["*"]
    resources: ["deployments"]
    verbs: ["get"]
```

✅ **Good:**

```yaml
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
```

### Instead of Wildcard Verbs

❌ **Bad:**

```yaml
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["*"]
```

✅ **Good:**

```yaml
rules:
  # Read-only access
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/status"]
    verbs: ["get", "list", "watch"]
  # Write access (separate rule for clarity)
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["create", "update", "patch"]
```

---

## Migration Examples

### Developer Read Access

```yaml
# Before: Overly broad
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]

# After: Explicit resources
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "services", "configmaps", "deployments", "jobs"]
    verbs: ["get", "list", "watch"]
```

### CI/CD Deployment

```yaml
# Before: Dangerous wildcards
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]

# After: Scoped permissions
rules:
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "pods"]
    verbs: ["get", "list", "create", "update", "patch", "delete"]
```

---

## Audit Script for Wildcard Usage

```bash
#!/bin/bash
# Finds Roles/ClusterRoles with wildcard permissions

kubectl get clusterroles -o json | jq -r '
  .items[] | . as $role | .rules[] |
  select(.apiGroups[]? == "*" or .resources[]? == "*" or .verbs[]? == "*") |
  "\($role.metadata.name): apiGroups=\(.apiGroups), resources=\(.resources), verbs=\(.verbs)"
'

kubectl get roles -A -o json | jq -r '
  .items[] | . as $role | .rules[] |
  select(.apiGroups[]? == "*" or .resources[]? == "*" or .verbs[]? == "*") |
  "\($role.metadata.namespace)/\($role.metadata.name)"
'
```

---

## Related Resources

- **[OPA RBAC Templates →](opa-rbac.md)** - Service account and namespace restrictions
- **[OPA Cluster-Admin Templates →](opa-rbac-cluster-admin.md)** - Prevent cluster-admin assignments
- **[OPA Privileged Verbs Templates →](opa-rbac-privileged-verbs.md)** - Block dangerous RBAC verbs
- **[OPA Pod Security Templates →](opa-pod-security.md)** - Privileged containers and host namespaces
- **[Decision Guide →](decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
