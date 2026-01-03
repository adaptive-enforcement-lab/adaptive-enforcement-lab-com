---
description: >-
  OPA Gatekeeper Linux capabilities templates. Enforce dropping ALL capabilities and restrict dangerous kernel-level privileges.
tags:
  - opa
  - gatekeeper
  - capabilities
  - pod-security
  - kubernetes
  - templates
---

# OPA Capabilities Templates

Enforces dropping ALL Linux capabilities and restricts dangerous kernel-level privileges. Capabilities grant kernel-level access that can bypass security controls and enable container escapes.

!!! danger "Capabilities = Kernel-Level Privileges"
    Linux capabilities grant kernel-level privileges without full root access. Always drop ALL capabilities and only add back specific safe ones with documented security review.

---

## Template 3: Required Capabilities Drop

Enforces dropping ALL Linux capabilities and optionally allows adding specific safe capabilities. Capabilities grant kernel-level privileges that can bypass security controls.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequiredcapabilitiesdrop
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredCapabilitiesDrop
      validation:
        openAPIV3Schema:
          properties:
            requiredDropCapabilities:
              type: array
              items:
                type: string
              description: "Capabilities that must be dropped"
            allowedCapabilities:
              type: array
              items:
                type: string
              description: "Capabilities allowed to be added"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredcapabilitiesdrop

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          missing_drops := get_missing_drops(container)
          count(missing_drops) > 0
          msg := sprintf("Container %v must drop capabilities: %v", [container.name, missing_drops])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          added := {cap | cap := container.securityContext.capabilities.add[_]}
          allowed := {cap | cap := input.parameters.allowedCapabilities[_]}
          forbidden := added - allowed
          count(forbidden) > 0
          msg := sprintf("Container %v has forbidden capabilities: %v", [container.name, forbidden])
        }

        get_missing_drops(container) = missing {
          required := {cap | cap := input.parameters.requiredDropCapabilities[_]}
          dropped := {cap | cap := container.securityContext.capabilities.drop[_]}
          missing := required - dropped
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredCapabilitiesDrop
metadata:
  name: require-drop-all-capabilities
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
    requiredDropCapabilities:
      - ALL
    allowedCapabilities:
      - NET_BIND_SERVICE  # Bind to ports < 1024
      - CHOWN             # Change file ownership
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `requiredDropCapabilities` | `["ALL"]` | Capabilities that must be dropped |
| `allowedCapabilities` | `["NET_BIND_SERVICE", "CHOWN"]` | Safe capabilities to allow |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-capabilities-drop.yaml

# Verify installation
kubectl get constrainttemplates k8srequiredcapabilitiesdrop
kubectl get k8srequiredcapabilitiesdrop

# Test without dropping ALL (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "nginx",
      "securityContext": {
        "capabilities": {
          "drop": ["MKNOD"]
        }
      }
    }]
  }
}'

# Test with dangerous capability (should fail)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "nginx",
      "securityContext": {
        "capabilities": {
          "drop": ["ALL"],
          "add": ["SYS_ADMIN"]
        }
      }
    }]
  }
}'

# Test with allowed capabilities (should pass)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "containers": [{
      "name": "test",
      "image": "nginx",
      "securityContext": {
        "capabilities": {
          "drop": ["ALL"],
          "add": ["NET_BIND_SERVICE"]
        }
      }
    }]
  }
}'
```

### Use Cases

1. **Kernel-level Protection**: Prevent containers from performing privileged kernel operations
2. **Least Privilege**: Ensure containers run with minimal capabilities
3. **Container Breakout Prevention**: Block capabilities that enable escapes
4. **SOC 2 Compliance**: Demonstrate capability restriction controls
5. **Defense in Depth**: Layer capabilities restrictions with other security controls

---

## Understanding Linux Capabilities

Linux capabilities break root privileges into distinct units. Instead of granting full root access, capabilities allow fine-grained privilege control.

### Dangerous Capabilities to Never Allow

| Capability | Risk | Attack Scenario |
|------------|------|-----------------|
| `SYS_ADMIN` | Critical | Mount filesystems, load kernel modules, bypass many checks |
| `SYS_PTRACE` | High | Debug other processes, read memory, inject code |
| `SYS_MODULE` | Critical | Load kernel modules, compromise host |
| `DAC_OVERRIDE` | High | Bypass file permission checks, read any file |
| `DAC_READ_SEARCH` | Medium | Bypass file read permission checks |
| `SYS_RAWIO` | High | Access /dev/mem, /dev/kmem (kernel memory) |
| `SYS_BOOT` | Critical | Reboot the host system |
| `NET_ADMIN` | Medium | Network configuration, sniffing, spoofing |

### Safe Capabilities (With Justification)

| Capability | Use Case | Security Considerations |
|------------|----------|------------------------|
| `NET_BIND_SERVICE` | Bind to ports < 1024 (HTTP/HTTPS) | Generally safe, prevents using high ports |
| `CHOWN` | Change file ownership | Safe if filesystem access is restricted |
| `SETUID` | Change process UID | Needed for some authentication flows |
| `SETGID` | Change process GID | Needed for some authentication flows |

### Checking Container Capabilities

```bash
# View capabilities of running container
kubectl exec <pod> -- capsh --print

# Find containers with dangerous capabilities
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].securityContext.capabilities.add[] |
  contains("SYS_ADMIN") or contains("SYS_PTRACE") or contains("SYS_MODULE")) |
  "\(.metadata.namespace)/\(.metadata.name)"
'
```

### Capability Attack Example

```yaml
# DANGEROUS - Never allow this
apiVersion: v1
kind: Pod
metadata:
  name: breakout-example
spec:
  containers:
    - name: attacker
      image: alpine
      securityContext:
        capabilities:
          add:
            - SYS_ADMIN  # Can mount host filesystem
      command:
        - sh
        - -c
        - |
          # Mount host filesystem from inside container
          mkdir /host
          mount /dev/sda1 /host
          # Now has full host filesystem access
          cat /host/etc/shadow
```

---

## Layered Defense Strategy

Combine capabilities restrictions with other security controls:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: myapp:v1.0.0
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        runAsUser: 1000
        capabilities:
          drop:
            - ALL
          add:
            - NET_BIND_SERVICE  # Only if needed for port 80/443
        readOnlyRootFilesystem: true
      volumeMounts:
        - name: tmp
          mountPath: /tmp
  volumes:
    - name: tmp
      emptyDir: {}
```

---

## Related Resources

- **[OPA Pod Security Templates →](opa-pod-security.md)** - Privileged containers and host namespaces
- **[OPA Security Context Templates →](opa-pod-security-contexts.md)** - Security context and privilege escalation
- **[OPA Image Security Templates →](opa-image-security.md)** - Registry allowlists and signing
- **[Kyverno Pod Security Templates →](kyverno-pod-security.md)** - Kubernetes-native alternative
- **[Decision Guide →](decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
