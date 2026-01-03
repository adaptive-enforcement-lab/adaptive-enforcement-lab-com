---
description: >-
  OPA Gatekeeper security context templates. Enforce runAsNonRoot and readOnlyRootFilesystem with complete Rego implementations.
tags:
  - opa
  - gatekeeper
  - security-context
  - pod-security
  - kubernetes
  - templates
---

# OPA Security Context Templates

Enforces required security context fields to ensure containers run as non-root and use read-only filesystems. These baseline security controls prevent privilege abuse and runtime modifications.

!!! warning "Security Context = Baseline Security"
    Security context fields provide baseline container security. Always require `runAsNonRoot: true` and `readOnlyRootFilesystem: true`.

---

## Template 4: Security Context Requirements

Enforces required security context fields: `runAsNonRoot`, `readOnlyRootFilesystem`, and user/group IDs. Running as root increases attack surface and violates least privilege.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8ssecuritycontextrequired
spec:
  crd:
    spec:
      names:
        kind: K8sSecurityContextRequired
      validation:
        openAPIV3Schema:
          properties:
            runAsNonRoot:
              type: boolean
              description: "Require runAsNonRoot: true"
            readOnlyRootFilesystem:
              type: boolean
              description: "Require readOnlyRootFilesystem: true"
            allowedUIDs:
              type: array
              items:
                type: integer
              description: "Allowed user IDs (empty = any non-root)"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8ssecuritycontextrequired

        violation[{"msg": msg, "details": {}}] {
          input.parameters.runAsNonRoot
          container := input_containers[_]
          not container_runs_as_non_root(container)
          msg := sprintf("Container %v must set runAsNonRoot: true", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          input.parameters.readOnlyRootFilesystem
          container := input_containers[_]
          not container.securityContext.readOnlyRootFilesystem
          msg := sprintf("Container %v must set readOnlyRootFilesystem: true", [container.name])
        }

        violation[{"msg": msg, "details": {}}] {
          count(input.parameters.allowedUIDs) > 0
          container := input_containers[_]
          uid := get_container_uid(container)
          not uid_allowed(uid)
          msg := sprintf("Container %v runs as UID %v which is not allowed", [container.name, uid])
        }

        container_runs_as_non_root(container) {
          container.securityContext.runAsNonRoot
        }

        container_runs_as_non_root(container) {
          input.review.object.spec.securityContext.runAsNonRoot
        }

        get_container_uid(container) = uid {
          uid := container.securityContext.runAsUser
        }

        get_container_uid(container) = uid {
          not container.securityContext.runAsUser
          uid := input.review.object.spec.securityContext.runAsUser
        }

        uid_allowed(uid) {
          allowed := input.parameters.allowedUIDs[_]
          uid == allowed
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sSecurityContextRequired
metadata:
  name: require-security-context
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
  parameters:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowedUIDs: []  # Empty = any non-root UID allowed
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `runAsNonRoot` | `true` | Require containers to run as non-root |
| `readOnlyRootFilesystem` | `true` | Require immutable root filesystem |
| `allowedUIDs` | `[]` | Restrict to specific UIDs (empty = any non-root) |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-security-context-required.yaml

# Verify installation
kubectl get constrainttemplates k8ssecuritycontextrequired
kubectl get k8ssecuritycontextrequired

# Test without runAsNonRoot (should fail)
kubectl run test --image=nginx

# Test without readOnlyRootFilesystem (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "securityContext": {
      "runAsNonRoot": true,
      "runAsUser": 1000
    },
    "containers": [{
      "name": "test",
      "image": "nginx"
    }]
  }
}'

# Test with complete security context (should pass)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "securityContext": {
      "runAsNonRoot": true,
      "runAsUser": 1000,
      "fsGroup": 1000
    },
    "containers": [{
      "name": "test",
      "image": "nginx",
      "securityContext": {
        "readOnlyRootFilesystem": true,
        "runAsNonRoot": true
      }
    }]
  }
}'
```

### Use Cases

1. **Least Privilege**: Prevent containers from running as root (UID 0)
2. **Immutable Infrastructure**: Enforce read-only filesystems to prevent runtime changes
3. **PCI-DSS Compliance**: Demonstrate non-root execution controls
4. **Supply Chain Security**: Prevent malicious images from gaining root access
5. **Auditability**: Ensure consistent security context across all workloads

---

## Related Resources

- **[OPA Privilege Escalation Prevention →](opa-pod-security-escalation.md)** - Block allowPrivilegeEscalation
- **[OPA Pod Security Templates →](opa-pod-security.md)** - Privileged containers and host namespaces
- **[OPA Capabilities Templates →](opa-pod-security-capabilities.md)** - Linux capabilities enforcement
- **[OPA Image Security Templates →](opa-image-security.md)** - Registry allowlists and signing
- **[Kyverno Pod Security Templates →](kyverno-pod-security.md)** - Kubernetes-native alternative
- **[Decision Guide →](decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
