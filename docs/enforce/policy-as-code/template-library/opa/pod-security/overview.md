---
description: >-
  OPA Gatekeeper pod security templates. Block privileged containers and host namespaces with complete Rego implementations.
tags:
  - opa
  - gatekeeper
  - pod-security
  - kubernetes
  - templates
---

# OPA Pod Security Templates

OPA/Gatekeeper constraint templates for pod security enforcement. Block privileged containers and host namespace access with production-tested Rego implementations.

!!! warning "Privileged Containers = Root Access"
    Running privileged containers gives pods unrestricted access to the host. These policies prevent common container escape vectors and enforce least-privilege principles.

---

## Template 1: Privileged Container Prevention

Blocks containers with `privileged: true` flag. Privileged containers bypass all security mechanisms and should never run in production.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblockprivileged
spec:
  crd:
    spec:
      names:
        kind: K8sBlockPrivileged
      validation:
        openAPIV3Schema:
          properties:
            exemptImages:
              type: array
              items:
                type: string
              description: "Container images exempt from this policy"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockprivileged

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          container.securityContext.privileged
          not exempt_image(container.image)
          msg := sprintf("Privileged container is not allowed: %v", [container.name])
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

        exempt_image(image) {
          exempt := input.parameters.exemptImages[_]
          startswith(image, exempt)
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockPrivileged
metadata:
  name: block-privileged-containers
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
      - kube-node-lease
  parameters:
    exemptImages: []
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `enforcementAction` | `deny` | Use `dryrun` for audit mode, `warn` for warnings |
| `exemptImages` | `[]` | Allow specific images (e.g., CNI plugins) |
| `excludedNamespaces` | System namespaces | Exclude cluster infrastructure |

### Validation Commands

```bash
# Apply constraint template and constraint
kubectl apply -f opa-privileged-prevention.yaml

# Verify installation
kubectl get constrainttemplates k8sblockprivileged
kubectl get k8sblockprivileged

# Test with privileged container (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "nginx",
      "securityContext": {
        "privileged": true
      }
    }]
  }
}'

# Check violations
kubectl get k8sblockprivileged block-privileged-containers -o yaml

# Audit existing violations
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.privileged == true) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Use Cases

1. **Container Breakout Prevention**: Block containers with full host access
2. **Multi-tenant Security**: Prevent privilege escalation across namespaces
3. **PCI-DSS Compliance**: Enforce least privilege requirements
4. **Supply Chain Security**: Ensure third-party workloads run unprivileged
5. **Regulatory Compliance**: Demonstrate security controls in audits

---

## Template 2: Host Namespace Restrictions

Blocks containers from accessing host namespaces (network, PID, IPC). Host namespace access breaks container isolation and enables lateral movement.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sblockhostnamespaces
spec:
  crd:
    spec:
      names:
        kind: K8sBlockHostNamespaces
      validation:
        openAPIV3Schema:
          properties:
            allowHostNetwork:
              type: boolean
              description: "Allow hostNetwork usage"
            allowHostPID:
              type: boolean
              description: "Allow hostPID usage"
            allowHostIPC:
              type: boolean
              description: "Allow hostIPC usage"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sblockhostnamespaces

        violation[{"msg": msg, "details": {}}] {
          input.review.object.spec.hostNetwork
          not input.parameters.allowHostNetwork
          msg := "Using hostNetwork is not allowed"
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.object.spec.hostPID
          not input.parameters.allowHostPID
          msg := "Using hostPID is not allowed"
        }

        violation[{"msg": msg, "details": {}}] {
          input.review.object.spec.hostIPC
          not input.parameters.allowHostIPC
          msg := "Using hostIPC is not allowed"
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          container.ports[_].hostPort
          msg := sprintf("Container %v uses hostPort which is not allowed", [container.name])
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockHostNamespaces
metadata:
  name: block-host-namespaces
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
    excludedNamespaces:
      - kube-system  # CNI plugins may need host network
  parameters:
    allowHostNetwork: false
    allowHostPID: false
    allowHostIPC: false
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `allowHostNetwork` | `false` | Allow host network (required for CNI plugins) |
| `allowHostPID` | `false` | Allow host PID namespace |
| `allowHostIPC` | `false` | Allow host IPC namespace |
| `excludedNamespaces` | System namespaces | Exempt CNI plugins and cluster components |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-host-namespace-restriction.yaml

# Verify installation
kubectl get constrainttemplates k8sblockhostnamespaces
kubectl get k8sblockhostnamespaces

# Test with hostNetwork (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "hostNetwork": true,
    "containers": [{
      "name": "test",
      "image": "nginx"
    }]
  }
}'

# Test with hostPID (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "hostPID": true,
    "containers": [{
      "name": "test",
      "image": "nginx"
    }]
  }
}'

# Audit existing violations
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.hostNetwork == true or .spec.hostPID == true or .spec.hostIPC == true) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Use Cases

1. **Container Isolation**: Prevent containers from accessing host processes or network
2. **Zero-Trust Networking**: Enforce container-level network segmentation
3. **Multi-tenant Security**: Prevent cross-tenant process visibility
4. **Container Escape Prevention**: Block common breakout techniques
5. **PCI-DSS Compliance**: Enforce network isolation requirements

---

## Related Resources

- **[OPA Capabilities Templates →](capabilities.md)** - Linux capabilities enforcement
- **[OPA Security Context Templates →](contexts.md)** - Security context and privilege escalation
- **[OPA Image Security Templates →](../image/security.md)** - Registry allowlists and signing
- **[OPA RBAC Templates →](../rbac/overview.md)** - Service account and role restrictions
- **[Kyverno Pod Security Templates →](../../kyverno/pod-security/standards.md)** - Kubernetes-native alternative
- **[Decision Guide →](../../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
