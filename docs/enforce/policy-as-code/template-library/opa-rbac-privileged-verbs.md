---
description: >-
  OPA Gatekeeper privileged RBAC verbs template. Block dangerous verbs like escalate, impersonate, and bind to prevent privilege escalation.
tags:
  - opa
  - gatekeeper
  - rbac
  - privilege-escalation
  - kubernetes
  - templates
---

# OPA Privileged Verbs Template

Prevents Roles and ClusterRoles from using dangerous verbs that enable privilege escalation. Verbs like `escalate`, `impersonate`, and `bind` allow attackers to gain higher permissions.

!!! danger "Dangerous Verbs = Privilege Escalation Paths"
    The `escalate`, `impersonate`, and `bind` verbs bypass normal RBAC checks and enable attackers to gain cluster-admin permissions indirectly.

---

## Template 4: Privileged Verbs Restrictions

Blocks creation of Roles and ClusterRoles with dangerous verbs that enable privilege escalation attacks.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblockprivilegedverbs
spec:
  crd:
    spec:
      names:
        kind: K8sBlockPrivilegedVerbs
      validation:
        openAPIV3Schema:
          properties:
            blockedVerbs:
              type: array
              items:
                type: string
              description: "Verbs that are not allowed in Roles/ClusterRoles"
            exemptRoles:
              type: array
              items:
                type: string
              description: "Role names exempt from this policy"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockprivilegedverbs

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind in ["Role", "ClusterRole"]
          not is_exempt_role
          rule := input.review.object.rules[_]
          verb := rule.verbs[_]
          is_blocked_verb(verb)
          msg := sprintf("%v %v contains blocked verb '%v' in rule with resources: %v",
            [input.review.kind.kind, input.review.object.metadata.name, verb, rule.resources])
        }

        is_blocked_verb(verb) {
          blocked := input.parameters.blockedVerbs[_]
          verb == blocked
        }

        is_blocked_verb(verb) {
          verb == "*"
        }

        is_exempt_role {
          role_name := input.review.object.metadata.name
          exempt := input.parameters.exemptRoles[_]
          role_name == exempt
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockPrivilegedVerbs
metadata:
  name: block-privileged-verbs
spec:
  enforcementAction: deny  # Use 'dryrun' for testing
  match:
    kinds:
      - apiGroups: ["rbac.authorization.k8s.io"]
        kinds: ["Role", "ClusterRole"]
  parameters:
    blockedVerbs:
      - escalate      # Bypass RBAC escalation prevention
      - impersonate   # Assume identity of other users/groups
      - bind          # Bind roles without owning permissions
    exemptRoles:
      # Platform controller roles that legitimately need these verbs
      - system:controller:namespace-controller
      - system:controller:clusterrole-aggregation-controller
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `blockedVerbs` | `["escalate", "impersonate", "bind"]` | Verbs that cannot be used |
| `exemptRoles` | System controllers | Roles that legitimately need dangerous verbs |
| `enforcementAction` | `deny` | Use `dryrun` to audit existing roles |

### Validation Commands

```bash
# Apply constraint template and constraint
kubectl apply -f opa-block-privileged-verbs.yaml

# Verify installation
kubectl get constrainttemplates k8sblockprivilegedverbs
kubectl get k8sblockprivilegedverbs

# Test with escalate verb (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-escalate
rules:
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["clusterroles"]
    verbs: ["escalate", "bind"]
EOF

# Test with safe verbs (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: test-safe
rules:
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
EOF

# Check violations
kubectl get k8sblockprivilegedverbs block-privileged-verbs -o yaml

# Audit existing roles with dangerous verbs
kubectl get clusterroles -o json | jq -r '
  .items[] |
  select(.rules[]?.verbs[]? | . == "escalate" or . == "impersonate" or . == "bind") |
  .metadata.name
'
```

### Use Cases

1. **Privilege Escalation Prevention**: Block indirect paths to cluster-admin
2. **RBAC Security Hardening**: Prevent verb-based permission bypass
3. **Compliance Requirements**: Demonstrate restricted privileged access controls
4. **Defense in Depth**: Layer verb restrictions with role binding controls
5. **Attack Surface Reduction**: Eliminate dangerous RBAC capabilities

---

## Understanding Dangerous Verbs

### Escalate Verb

The `escalate` verb allows creating or updating Roles/ClusterRoles with permissions the user doesn't have.

**Attack Scenario:**

```yaml
# Attacker has permission to create Roles but not to read secrets
# Without escalate protection, they can create a Role that reads secrets

apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: production
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]  # Attacker doesn't have this permission
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: attacker-secret-access
  namespace: production
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-reader
subjects:
  - kind: User
    name: attacker
```

**Prevention:** Kubernetes blocks this by default, but explicit policy enforcement adds defense in depth.

### Impersonate Verb

The `impersonate` verb allows assuming the identity of other users, groups, or service accounts.

**Attack Scenario:**

```yaml
# Attacker with impersonate permission can act as cluster-admin

# First, create a Role that allows impersonation
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: impersonator
rules:
  - apiGroups: [""]
    resources: ["users"]
    verbs: ["impersonate"]
    resourceNames: ["cluster-admin"]

# Then, use kubectl with impersonation
kubectl get secrets -A --as=cluster-admin
```

**Real-world risk:** Any compromised service account with impersonate can bypass all RBAC controls.

### Bind Verb

The `bind` verb allows creating RoleBindings to Roles the user doesn't have permission to use.

**Attack Scenario:**

```yaml
# Attacker has bind permission but not cluster-admin
# They can bind cluster-admin to themselves

apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: attacker-escalation
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin  # Pre-existing role
subjects:
  - kind: User
    name: attacker
```

**Prevention:** Block `bind` verb except for system controllers that legitimately need it.

---

## Dangerous Verbs Reference

| Verb | Risk Level | Attack Path | Legitimate Use Cases |
|------|-----------|-------------|----------------------|
| `escalate` | Critical | Create roles with higher permissions | RBAC controller aggregating roles |
| `impersonate` | Critical | Assume identity of admin users | Debug tools, admission controllers |
| `bind` | Critical | Bind high-privilege roles without permission | Namespace controller, role aggregation |
| `*` (wildcard) | High | Grant all verbs including future ones | Should never be used (use explicit verbs) |
| `create` (on roles/rolebindings) | Medium | Combined with escalate/bind | RBAC management tools |
| `patch` (on roles/rolebindings) | Medium | Modify existing permissions | GitOps controllers |
| `delete` (on rolebindings) | Low | DoS by removing permissions | Cleanup jobs |

---

## Defense in Depth Strategy

Combine verb restrictions with other RBAC controls:

```yaml
# Layer 1: Block dangerous verbs in Roles
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockPrivilegedVerbs
metadata:
  name: block-privileged-verbs
spec:
  parameters:
    blockedVerbs: ["escalate", "impersonate", "bind"]

# Layer 2: Block cluster-admin assignments
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockClusterAdmin
metadata:
  name: block-cluster-admin-role
spec:
  parameters:
    blockedRoles: ["cluster-admin"]

# Layer 3: Require namespace isolation for RoleBindings
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRoleBindingNamespace
metadata:
  name: rolebinding-namespace-enforcement

# Layer 4: Audit RBAC changes
# Monitor ClusterRole/Role/RoleBinding/ClusterRoleBinding changes in audit logs
```

---

## Audit Script for Dangerous Verbs

```bash
#!/bin/bash
# audit-dangerous-verbs.sh
# Finds all Roles and ClusterRoles with escalate, impersonate, or bind verbs

echo "=== ClusterRoles with Dangerous Verbs ==="
kubectl get clusterroles -o json | jq -r '
  .items[] |
  . as $role |
  .rules[] |
  select(.verbs[]? | . == "escalate" or . == "impersonate" or . == "bind" or . == "*") |
  "\($role.metadata.name): \(.verbs | join(", ")) on \(.resources | join(", "))"
' | sort | uniq

echo ""
echo "=== Roles with Dangerous Verbs ==="
kubectl get roles -A -o json | jq -r '
  .items[] |
  . as $role |
  .rules[] |
  select(.verbs[]? | . == "escalate" or . == "impersonate" or . == "bind" or . == "*") |
  "\($role.metadata.namespace)/\($role.metadata.name): \(.verbs | join(", ")) on \(.resources | join(", "))"
' | sort | uniq

echo ""
echo "=== Service Accounts with Impersonate Permission ==="
kubectl get clusterrolebindings,rolebindings -A -o json | jq -r '
  .items[] |
  select(.roleRef.name | . != null) as $binding |
  .subjects[]? |
  select(.kind == "ServiceAccount") |
  "\($binding.metadata.name): \(.namespace)/\(.name)"
'
```

---

## Related Resources

- **[OPA RBAC Templates →](opa-rbac.md)** - Service account and namespace restrictions
- **[OPA Cluster-Admin Templates →](opa-rbac-cluster-admin.md)** - Prevent cluster-admin assignments
- **[OPA Wildcard Templates →](opa-rbac-wildcards.md)** - Prevent wildcard resource permissions
- **[OPA Pod Security Templates →](opa-pod-security.md)** - Privileged containers and host namespaces
- **[Decision Guide →](decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
