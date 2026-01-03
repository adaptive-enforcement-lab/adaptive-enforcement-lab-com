---
description: >-
  OPA Gatekeeper RBAC templates. Enforce service account restrictions and role binding limits with complete Rego implementations.
tags:
  - opa
  - gatekeeper
  - rbac
  - kubernetes
  - templates
---

# OPA RBAC Templates

OPA/Gatekeeper constraint templates for RBAC security enforcement. Block default service accounts, enforce namespace boundaries, and prevent privilege escalation through production-tested Rego implementations.

!!! warning "RBAC Misconfigurations = Privilege Escalation"
    Overly permissive RBAC allows attackers to escalate privileges, access secrets, and move laterally across namespaces. These policies enforce least-privilege RBAC at admission time.

---

## Template 1: Service Account Restrictions

Blocks usage of default service accounts and auto-mounted tokens. Default service accounts have broad permissions and are common attack targets.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblockdefaultsa
spec:
  crd:
    spec:
      names:
        kind: K8sBlockDefaultSA
      validation:
        openAPIV3Schema:
          properties:
            allowDefaultSANamespaces:
              type: array
              items:
                type: string
              description: "Namespaces allowed to use default service account"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockdefaultsa

        violation[{"msg": msg, "details": {}}] {
          input.review.object.spec.serviceAccountName == "default"
          not exempt_namespace
          msg := "Using the default service account is not allowed. Create a dedicated service account."
        }

        violation[{"msg": msg, "details": {}}] {
          not has_key(input.review.object.spec, "serviceAccountName")
          input.review.object.spec.automountServiceAccountToken != false
          not exempt_namespace
          msg := "Must explicitly set serviceAccountName or set automountServiceAccountToken: false"
        }

        exempt_namespace {
          namespace := input.review.object.metadata.namespace
          allowed := input.parameters.allowDefaultSANamespaces[_]
          namespace == allowed
        }

        has_key(obj, key) {
          _ = obj[key]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockDefaultSA
metadata:
  name: block-default-service-account
spec:
  enforcementAction: deny  # Use 'dryrun' for testing
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      - apiGroups: ["batch"]
        kinds: ["Job", "CronJob"]
    excludedNamespaces:
      - kube-system
      - kube-public
  parameters:
    allowDefaultSANamespaces: []
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `allowDefaultSANamespaces` | `[]` | Namespaces exempt from default SA blocking |
| `enforcementAction` | `deny` | Use `dryrun` for audit mode |
| `excludedNamespaces` | System namespaces | Exempt cluster infrastructure |

### Validation Commands

```bash
# Apply constraint template and constraint
kubectl apply -f opa-block-default-sa.yaml

# Verify installation
kubectl get constrainttemplates k8sblockdefaultsa
kubectl get k8sblockdefaultsa

# Test with default service account (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "serviceAccountName": "default",
    "containers": [{
      "name": "test",
      "image": "nginx"
    }]
  }
}'

# Test with dedicated service account (should pass)
kubectl create serviceaccount app-sa -n default
kubectl run test --image=nginx --serviceaccount=app-sa

# Check violations
kubectl get k8sblockdefaultsa block-default-service-account -o yaml

# Audit existing default SA usage
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.serviceAccountName == "default") |
  "\(.metadata.namespace)/\(.metadata.name)"
'
```

### Use Cases

1. **Least Privilege**: Force teams to create service accounts with minimal permissions
2. **Attack Surface Reduction**: Prevent token theft from broadly-scoped default SA
3. **Multi-tenant Security**: Isolate workload permissions across teams
4. **Compliance Requirements**: Demonstrate principle of least privilege (SOC 2, PCI-DSS)
5. **Token Theft Prevention**: Reduce impact of compromised pods with limited SA permissions

---

## Template 2: Role Binding Namespace Enforcement

Prevents RoleBindings from referencing Roles or ServiceAccounts in different namespaces. Cross-namespace bindings enable privilege escalation.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srolebindingnamespace
spec:
  crd:
    spec:
      names:
        kind: K8sRoleBindingNamespace
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srolebindingnamespace

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "RoleBinding"
          roleref := input.review.object.roleRef
          roleref.kind == "Role"
          namespace := input.review.object.metadata.namespace
          # RoleRef doesn't have namespace field (implicitly same namespace)
          # This is OK, just checking subjects
          subject := input.review.object.subjects[_]
          subject_namespace := object.get(subject, "namespace", "")
          subject_namespace != ""
          subject_namespace != namespace
          msg := sprintf("RoleBinding %v in namespace %v references subject in different namespace: %v",
            [input.review.object.metadata.name, namespace, subject_namespace])
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.kind.kind == "ClusterRoleBinding"
          subject := input.review.object.subjects[_]
          subject.kind == "ServiceAccount"
          not has_namespace(subject)
          msg := sprintf("ClusterRoleBinding %v references ServiceAccount without namespace: %v",
            [input.review.object.metadata.name, subject.name])
        }

        has_namespace(subject) {
          subject.namespace
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRoleBindingNamespace
metadata:
  name: rolebinding-namespace-enforcement
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: ["rbac.authorization.k8s.io"]
        kinds: ["RoleBinding", "ClusterRoleBinding"]
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `enforcementAction` | `deny` | Use `dryrun` for gradual rollout |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-rolebinding-namespace.yaml

# Verify installation
kubectl get constrainttemplates k8srolebindingnamespace
kubectl get k8srolebindingnamespace

# Test with cross-namespace subject (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: test-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
  - kind: ServiceAccount
    name: my-sa
    namespace: other-namespace  # Cross-namespace reference
EOF

# Test with same-namespace subject (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: test-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-reader
subjects:
  - kind: ServiceAccount
    name: my-sa
    namespace: default  # Same namespace
EOF

# Audit existing cross-namespace bindings
kubectl get rolebindings -A -o json | jq -r '
  .items[] |
  select(.subjects[]?.namespace != .metadata.namespace) |
  "\(.metadata.namespace)/\(.metadata.name)"
'
```

### Use Cases

1. **Privilege Escalation Prevention**: Block cross-namespace RBAC abuse
2. **Namespace Isolation**: Enforce strict namespace boundaries for multi-tenancy
3. **Least Privilege**: Prevent overly broad permissions spanning namespaces
4. **Zero-Trust Security**: Deny lateral movement via RBAC misconfigurations
5. **Compliance**: Demonstrate tenant isolation controls (PCI-DSS, HIPAA)

---

## Related Resources

- **[OPA Cluster-Admin Templates →](cluster-admin.md)** - Prevent cluster-admin role assignments
- **[OPA Privileged Verbs Templates →](privileged-verbs.md)** - Block dangerous RBAC verbs
- **[OPA Wildcard Templates →](wildcards.md)** - Prevent wildcard resource permissions
- **[OPA Pod Security Templates →](../opa-pod-security/overview.md)** - Privileged containers and host namespaces
- **[OPA Image Security Templates →](../opa-image/security.md)** - Registry allowlists and signing
- **[Kyverno Pod Security Templates →](../kyverno-pod-security/standards.md)** - Kubernetes-native alternative
- **[Decision Guide →](../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
