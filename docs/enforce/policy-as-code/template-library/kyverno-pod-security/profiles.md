---
description: >-
  Kyverno security profile templates for seccomp and AppArmor. Enforce runtime security profiles to reduce container attack surface and restrict system calls.
tags:
  - kyverno
  - pod-security
  - seccomp
  - apparmor
  - kubernetes
  - templates
---

# Kyverno Pod Security Profiles

Security profile policies for seccomp and AppArmor. These policies enforce runtime security mechanisms that restrict container capabilities and reduce the attack surface.

!!! tip "Defense in Depth with Security Profiles"
    Seccomp and AppArmor provide complementary security layers. Seccomp filters system calls, while AppArmor enforces mandatory access control. Use both for maximum protection.

---

## Template 4: Seccomp Profile Enforcement

Requires seccomp profiles for containers. Seccomp (Secure Computing Mode) restricts the system calls a container can make, reducing the attack surface.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-seccomp-profile
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-seccomp-profile
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Seccomp profile must be set to RuntimeDefault or Localhost"
        anyPattern:
          # Pod-level seccomp
          - spec:
              template?:
                spec:
                  securityContext:
                    seccompProfile:
                      type: RuntimeDefault | Localhost
          # Container-level seccomp
          - spec:
              template?:
                spec:
                  containers:
                    - securityContext:
                        seccompProfile:
                          type: RuntimeDefault | Localhost
    - name: deny-unconfined-seccomp
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Seccomp profile type 'Unconfined' is not allowed"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.securityContext.seccompProfile.type || '' }}"
                operator: Equals
                value: "Unconfined"
              - key: "{{ request.object.spec.template.spec.containers[].securityContext.seccompProfile.type || '' }}"
                operator: AnyIn
                value: ["Unconfined"]
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for initial rollout |
| `seccompProfile.type` | `RuntimeDefault` or `Localhost` | Allowed profile types |
| `custom-profile-path` | `/var/lib/kubelet/seccomp/profiles` | Location for custom profiles |

### Validation Commands

```bash
# Apply policy
kubectl apply -f seccomp-policy.yaml

# Test without seccomp (should fail)
kubectl run test --image=nginx

# Test with RuntimeDefault (should pass)
kubectl run test --image=nginx --overrides='
{
  "spec": {
    "securityContext": {
      "seccompProfile": {
        "type": "RuntimeDefault"
      }
    }
  }
}'

# Check existing pods without seccomp
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.securityContext.seccompProfile == null) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Use Cases

1. **Syscall Filtering**: Block dangerous system calls (e.g., kernel module loading, BPF)
2. **Exploit Prevention**: Reduce attack surface for kernel vulnerabilities
3. **Compliance Standards**: Meet CIS Kubernetes Benchmark requirements
4. **Custom Profiles**: Deploy workload-specific seccomp profiles for high-security applications

### Creating Custom Seccomp Profiles

Generate a baseline seccomp profile from a running container:

```bash
# Install seccomp profile generator
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/security-profiles-operator/main/deploy/operator.yaml

# Record syscalls from a running pod
kubectl label pod <pod-name> security.kubernetes.io/seccomp-profile=runtime/default
kubectl annotate pod <pod-name> container.seccomp.security.alpha.kubernetes.io/<container-name>=runtime/default

# Extract and save the profile
kubectl get seccompprofile -n <namespace> -o yaml > custom-seccomp.yaml
```

Example custom seccomp profile:

```json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["read", "write", "open", "close", "stat"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
```

---

## Template 5: AppArmor Profile Requirements

Enforces AppArmor profiles for containers. AppArmor provides mandatory access control to restrict program capabilities.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-apparmor-profile
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-apparmor-annotation
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "AppArmor profile annotation is required. Use 'runtime/default' or a custom profile."
        pattern:
          metadata:
            annotations:
              container.apparmor.security.beta.kubernetes.io/*: "runtime/default | localhost/*"
    - name: deny-unconfined-apparmor
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "AppArmor profile 'unconfined' is not allowed"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.annotations.\"container.apparmor.security.beta.kubernetes.io/*\" || '' }}"
                operator: Equals
                value: "unconfined"
    - name: validate-apparmor-profile-exists
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      preconditions:
        any:
          - key: "{{ request.object.metadata.annotations.\"container.apparmor.security.beta.kubernetes.io/*\" || '' }}"
            operator: In
            value: ["localhost/*"]
      validate:
        message: "Custom AppArmor profile must be loaded on nodes"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.annotations.\"container.apparmor.security.beta.kubernetes.io/*\" }}"
                operator: NotEquals
                value: "runtime/default"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for gradual rollout |
| `default-profile` | `runtime/default` | Default AppArmor profile |
| `custom-profiles` | `localhost/*` | Path pattern for custom profiles |
| `profile-location` | `/etc/apparmor.d` | Node location for profiles |

### Validation Commands

```bash
# Apply policy
kubectl apply -f apparmor-policy.yaml

# Test without AppArmor (should fail)
kubectl run test --image=nginx

# Test with runtime/default (should pass)
kubectl run test --image=nginx --annotations='container.apparmor.security.beta.kubernetes.io/test=runtime/default'

# List available AppArmor profiles on node
kubectl debug node/node-name -it --image=ubuntu -- chroot /host apparmor_status

# Check pods without AppArmor annotations
kubectl get pods -A -o json | jq -r '.items[] | select(.metadata.annotations["container.apparmor.security.beta.kubernetes.io"] == null) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Use Cases

1. **File Access Control**: Restrict container file system access to specific paths
2. **Network Restrictions**: Limit network capabilities at the MAC layer
3. **Compliance Requirements**: Meet regulatory requirements for mandatory access control
4. **Defense in Depth**: Add another security layer beyond seccomp and capabilities

### Creating Custom AppArmor Profiles

Example AppArmor profile for a web application:

```text
#include <tunables/global>

profile k8s-web-app flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>

  # Allow network access
  network inet tcp,
  network inet udp,

  # Allow specific file paths
  /app/** r,
  /tmp/** rw,
  /var/log/** w,

  # Deny everything else
  deny /** w,
}
```

Deploy AppArmor profile to nodes:

```bash
# Load profile on each node
sudo apparmor_parser -r -W /etc/apparmor.d/k8s-web-app

# Verify profile is loaded
sudo apparmor_status | grep k8s-web-app

# Apply to pod via annotation
kubectl annotate deployment web-app \
  container.apparmor.security.beta.kubernetes.io/web-app=localhost/k8s-web-app
```

---

## Combining Security Profiles

For maximum security, use both seccomp and AppArmor together:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
  annotations:
    container.apparmor.security.beta.kubernetes.io/app: runtime/default
spec:
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      image: nginx:1.21
      securityContext:
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        runAsUser: 1000
        capabilities:
          drop:
            - ALL
        readOnlyRootFilesystem: true
```

---

## Related Resources

- **[Kyverno Pod Security →](standards.md)** - Core pod security policies
- **[Kyverno Image Validation →](../kyverno-image/validation.md)** - Registry allowlists and tag validation
- **[Kyverno Resource Limits →](../kyverno-resource/limits.md)** - CPU and memory enforcement
- **[Template Library Overview →](index.md)** - Back to main page
