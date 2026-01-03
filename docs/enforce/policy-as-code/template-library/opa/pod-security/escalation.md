---
description: >-
  OPA Gatekeeper privilege escalation prevention. Block allowPrivilegeEscalation to prevent setuid/setgid attacks with complete Rego implementation and debugging guide.
tags:
  - opa
  - gatekeeper
  - privilege-escalation
  - pod-security
  - kubernetes
  - templates
---

# OPA Privilege Escalation Prevention

Blocks containers from escalating privileges via `allowPrivilegeEscalation` flag. Prevents setuid/setgid binaries from gaining elevated privileges during runtime.

!!! danger "Privilege Escalation = Root Access"
    Allowing privilege escalation enables setuid binaries to gain root privileges. Always set `allowPrivilegeEscalation: false` unless you have a documented security exception.

---

## Template 5: Privilege Escalation Prevention

Blocks containers from escalating privileges via `allowPrivilegeEscalation` flag. Prevents setuid/setgid binaries from gaining elevated privileges during runtime.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblockprivilegeescalation
spec:
  crd:
    spec:
      names:
        kind: K8sBlockPrivilegeEscalation
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockprivilegeescalation

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          allows_escalation(container)
          msg := sprintf("Container %v must set allowPrivilegeEscalation: false", [container.name])
        }

        allows_escalation(container) {
          not has_security_context(container)
        }

        allows_escalation(container) {
          container.securityContext.allowPrivilegeEscalation == true
        }

        allows_escalation(container) {
          has_security_context(container)
          not has_field(container.securityContext, "allowPrivilegeEscalation")
        }

        has_security_context(container) {
          container.securityContext
        }

        has_field(obj, field) {
          obj[field]
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.ephemeralContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockPrivilegeEscalation
metadata:
  name: block-privilege-escalation
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      - apiGroups: ["batch"]
        kinds: ["Job", "CronJob"]
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `enforcementAction` | `deny` | Use `dryrun` for audit mode |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-privilege-escalation.yaml

# Verify installation
kubectl get constrainttemplates k8sblockprivilegeescalation
kubectl get k8sblockprivilegeescalation

# Test with allowPrivilegeEscalation: true (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "nginx",
      "securityContext": {
        "allowPrivilegeEscalation": true
      }
    }]
  }
}'

# Test without security context (should fail - defaults to true)
kubectl run test --image=nginx

# Test with allowPrivilegeEscalation: false (should pass)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "nginx",
      "securityContext": {
        "allowPrivilegeEscalation": false
      }
    }]
  }
}'

# Audit existing workloads
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.allowPrivilegeEscalation != false) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Use Cases

1. **Setuid/Setgid Prevention**: Block privilege escalation via setuid binaries
2. **Container Breakout Prevention**: Prevent runtime privilege gains
3. **SOC 2 Compliance**: Demonstrate privilege restriction controls
4. **Supply Chain Security**: Prevent malicious binaries from escalating privileges
5. **Defense in Depth**: Layer with other security controls for comprehensive protection

---

## Understanding OPA/Gatekeeper Policy Components

### ConstraintTemplate Structure

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sexamplepolicy          # Template name (lowercase)
spec:
  crd:
    spec:
      names:
        kind: K8sExamplePolicy     # Constraint kind (CamelCase)
      validation:
        openAPIV3Schema:           # Define parameters
          properties:
            param1:
              type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sexamplepolicy   # Must match template name

        violation[{"msg": msg}] {
          # Rego logic here
        }
```

### Constraint Structure

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sExamplePolicy             # Matches ConstraintTemplate kind
metadata:
  name: example-policy-instance    # Instance name
spec:
  enforcementAction: deny          # deny, dryrun, warn
  match:
    kinds:                         # Resources to validate
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:            # Namespaces to skip
      - kube-system
  parameters:                      # Values for template parameters
    param1: "value"
```

### Common Rego Patterns

```rego
# Input structure
input.review.object                     # The resource being validated
input.review.object.spec.containers     # Container array
input.parameters                        # Constraint parameters

# Array iteration
container := input.review.object.spec.containers[_]

# String operations
startswith(image, "registry.example.com/")
contains(image, ":latest")

# Set operations
required := {"CAP1", "CAP2"}
dropped := {cap | cap := container.securityContext.capabilities.drop[_]}
missing := required - dropped

# Conditionals
not container.securityContext.privileged  # Must be false
count(missing) > 0                        # Count check
```

### Debugging OPA Policies

```bash
# Check constraint template status
kubectl get constrainttemplates
kubectl describe constrainttemplate k8sblockprivileged

# Check constraint status and violations
kubectl get constraints
kubectl describe k8sblockprivileged block-privileged-containers

# View audit results
kubectl get k8sblockprivileged -o jsonpath='{.status.violations}'

# Test policy in dryrun mode
kubectl patch k8sblockprivileged block-privileged-containers \
  --type=merge -p '{"spec":{"enforcementAction":"dryrun"}}'

# Check gatekeeper logs
kubectl logs -n gatekeeper-system -l control-plane=controller-manager --tail=100
```

### Rego Unit Testing

```rego
# test_k8sblockprivilegeescalation_test.rego
package k8sblockprivilegeescalation

test_privileged_container_blocked {
  input := {
    "review": {
      "object": {
        "spec": {
          "containers": [{
            "name": "test",
            "securityContext": {
              "allowPrivilegeEscalation": true
            }
          }]
        }
      }
    }
  }
  count(violation) > 0
}

test_secure_container_allowed {
  input := {
    "review": {
      "object": {
        "spec": {
          "containers": [{
            "name": "test",
            "securityContext": {
              "allowPrivilegeEscalation": false
            }
          }]
        }
      }
    }
  }
  count(violation) == 0
}
```

Run tests with:

```bash
# Using OPA CLI
opa test -v k8sblockprivilegeescalation.rego \
  k8sblockprivilegeescalation_test.rego
```

---

## Related Resources

- **[OPA Security Context Templates →](contexts.md)** - runAsNonRoot and readOnlyRootFilesystem
- **[OPA Pod Security Templates →](overview.md)** - Privileged containers and host namespaces
- **[OPA Capabilities Templates →](capabilities.md)** - Linux capabilities enforcement
- **[OPA Image Security Templates →](../image/security.md)** - Registry allowlists and signing
- **[OPA RBAC Templates →](../rbac/overview.md)** - Service account and role restrictions
- **[Kyverno Pod Security Templates →](../../kyverno/pod-security/standards.md)** - Kubernetes-native alternative
- **[Decision Guide →](../../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
