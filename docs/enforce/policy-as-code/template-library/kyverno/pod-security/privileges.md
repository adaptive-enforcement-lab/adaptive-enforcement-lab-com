---
title: Kyverno Privilege Escalation Prevention
description: >-
  Kyverno privilege escalation prevention templates. Block setuid, setgid, and privileged container execution to enforce least privilege principles.
tags:
  - kyverno
  - pod-security
  - privilege-escalation
  - kubernetes
  - templates
---
# Kyverno Privilege Escalation Prevention

Blocks containers from escalating privileges during runtime. These policies prevent `setuid`, `setgid`, and other privilege elevation mechanisms that could compromise cluster security.

!!! danger "Privilege Escalation = Root Access"
    Allowing privilege escalation in containers can lead to container breakouts and node compromise. Always set `allowPrivilegeEscalation: false` unless you have a documented security exception.

---

## Template 3: Privilege Escalation Prevention

Blocks containers from escalating privileges during runtime. Prevents `setuid`, `setgid`, and other privilege elevation mechanisms.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prevent-privilege-escalation
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: deny-privilege-escalation
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Privilege escalation is not allowed"
        pattern:
          spec:
            template?:
              spec:
                containers:
                  - securityContext:
                      allowPrivilegeEscalation: false
    - name: enforce-no-new-privileges
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
          selector:
            matchLabels:
              security.enforce: "strict"
      validate:
        message: "Containers with strict security must set securityContext.allowPrivilegeEscalation=false"
        pattern:
          spec:
            template?:
              spec:
                containers:
                  - securityContext:
                      allowPrivilegeEscalation: false
                initContainers?:
                  - securityContext:
                      allowPrivilegeEscalation: false
    - name: deny-privileged-flag
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
      validate:
        message: "Privileged containers are not allowed (use allowPrivilegeEscalation=false)"
        pattern:
          spec:
            template?:
              spec:
                containers:
                  - securityContext:
                      privileged: false
                initContainers?:
                  - securityContext:
                      privileged: false
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for testing |
| `allowPrivilegeEscalation` | `false` | Block setuid/setgid binaries |
| `security.enforce` label | `strict` | Target namespaces for stricter enforcement |

### Validation Commands

```bash
# Apply policy
kubectl apply -f privilege-escalation-policy.yaml

# Test with allowPrivilegeEscalation=true (should fail)
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

# Test with allowPrivilegeEscalation=false (should pass)
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
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].securityContext.allowPrivilegeEscalation == true) | "\(.metadata.namespace)/\(.metadata.name)"'
```

### Use Cases

1. **Container Breakout Prevention**: Block privilege escalation exploits
2. **Least Privilege Enforcement**: Ensure containers run with minimal permissions
3. **SOC 2 Compliance**: Demonstrate privilege restriction controls
4. **Multi-tenant Security**: Prevent tenant privilege escalation in shared clusters

---

## Understanding Privilege Escalation

Privilege escalation in containers occurs when a process gains more privileges than it started with. This typically happens through:

### setuid and setgid Binaries

Programs with the setuid or setgid bit can run with elevated privileges:

```bash
# Example: Find setuid binaries in a container
find / -perm -4000 -type f 2>/dev/null

# Common setuid binaries that enable escalation
/usr/bin/passwd
/usr/bin/sudo
/bin/su
```

Setting `allowPrivilegeEscalation: false` prevents these binaries from working, even if they're present in the container image.

### Kernel Capabilities

Even without full root access, certain capabilities can enable privilege escalation:

```yaml
# Dangerous capabilities to avoid
securityContext:
  capabilities:
    drop:
      - ALL  # Drop all capabilities
    add:
      # NEVER add these without security review:
      # - SYS_ADMIN   (mount filesystems, load kernel modules)
      # - SYS_PTRACE  (debug other processes, read memory)
      # - SYS_MODULE  (load kernel modules)
      # - DAC_OVERRIDE (bypass file permission checks)
```

### Privileged Containers

Privileged containers have unrestricted access to the host:

```yaml
# DANGEROUS - Full host access
spec:
  containers:
    - name: danger
      securityContext:
        privileged: true  # Never use in production
```

---

## Layered Security Approach

Combine privilege escalation prevention with other security controls:

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
        readOnlyRootFilesystem: true
```

---

## Related Resources

- **[Kyverno Pod Security →](standards.md)** - Core pod security policies
- **[Kyverno Pod Security Profiles →](profiles.md)** - Seccomp and AppArmor enforcement
- **[Kyverno Image Validation →](../image/validation.md)** - Registry allowlists and tag validation
- **[Template Library Overview →](index.md)** - Back to main page
