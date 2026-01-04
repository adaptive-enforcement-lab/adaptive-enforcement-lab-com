---
title: Defense in Depth
description: >-
  Defense in depth security pattern for Kubernetes. Multiple layers of security controls including pod security contexts, network policies, and resource limits.
tags:
  - security
  - kubernetes
  - defense-in-depth
  - hardening
---
# Defense in Depth

Defense in depth layers multiple independent security controls. Compromise at one layer does not compromise the system.

## Core Principle

No single security control is perfect. Defense in depth assumes breach and builds redundancy.

**Key Properties**:

- Multiple independent layers of protection
- Each layer adds cost to attackers
- Compromise of one layer does not cascade
- Each control has different failure modes

## Pod Security Contexts

Pod security contexts define the security posture at the container level.

### Minimal Security Context

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: myapp:1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
```

**What This Does**:

- `runAsNonRoot: true` - Rejects containers running as root
- `runAsUser: 10001` - Explicit non-root UID
- `readOnlyRootFilesystem: true` - Prevents filesystem modifications
- `allowPrivilegeEscalation: false` - Blocks privilege escalation exploits
- `capabilities.drop: [ALL]` - Removes all Linux capabilities
- `seccompProfile: RuntimeDefault` - Restricts syscall access

!!! warning "Most Breaches Exploit Convenience Shortcuts"
    Setting `allowPrivilegeEscalation: true` or `runAsUser: 0` is the security equivalent of leaving your front door unlocked. Attackers look for these first.

## Common Mistakes

### Anti-Pattern: Privilege Escalation for Convenience

```yaml
# DON'T DO THIS
securityContext:
  allowPrivilegeEscalation: true  # Defeats most controls
  runAsUser: 0                     # Running as root
```

**Why This Is Dangerous**:

- Allows container to gain more privileges than parent process
- Opens door to kernel exploits
- Bypasses most pod security controls

**Correct Pattern**:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 10001
```

## Network Policies

Network policies enforce network-level isolation between pods.

### Default-Deny Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**What This Does**:

- Applies to all pods in namespace (`podSelector: {}`)
- Denies all ingress traffic by default
- Denies all egress traffic by default
- Requires explicit allow rules for communication

### Explicit Allow Rules

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-gateway-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: api-gateway
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend-service
    ports:
    - protocol: TCP
      port: 9000
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
```

**What This Allows**:

1. **Ingress**: Only from ingress-nginx namespace on port 8080
2. **Egress**: Only to backend-service on port 9000
3. **DNS**: Only to kube-dns in kube-system namespace

### Network Policy Patterns

See [integration.md](integration.md) for complete examples of database access patterns and external API access configurations.

## Resource Limits

Resource limits prevent denial-of-service attacks and resource exhaustion.

### CPU and Memory Limits

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-limited-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
```

**Why This Matters**:

- **Requests**: Guaranteed allocation (scheduler uses this)
- **Limits**: Maximum allowed (prevents noisy neighbor problems)
- **CPU throttling**: Slows down runaway processes
- **OOM kills**: Prevents memory exhaustion attacks

### ResourceQuota for Namespaces

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "100"
    requests.memory: "200Gi"
    limits.cpu: "200"
    limits.memory: "400Gi"
    pods: "100"
    services: "50"
```

**What This Enforces**:

- Maximum total resources for namespace
- Prevents single team from consuming all cluster resources
- Forces developers to think about resource usage

## Read-Only Filesystems

Read-only root filesystems prevent malware persistence and file modification.

### Read-Only Root with Temporary Directories

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readonly-pod
spec:
  containers:
  - name: app
    image: myapp:1.0
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/app
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
```

**What This Prevents**:

- Malware writing to root filesystem
- Log file tampering
- Configuration file modification
- Persistence across container restarts

**Where Writes Are Allowed**:

- `/tmp` via emptyDir (ephemeral)
- `/var/cache/app` via emptyDir (ephemeral)
- All data cleared on pod restart

## Layered Security Example

Complete example combining all defense-in-depth controls:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: defense-in-depth-pod
  namespace: production
  labels:
    app: secure-api
    role: backend
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: api
    image: secure-api:1.0
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "512Mi"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
  volumes:
  - name: tmp
    emptyDir: {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: secure-api-policy
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: secure-api
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: postgres
    ports:
    - protocol: TCP
      port: 5432
```

**Security Layers**:

1. **Process isolation**: Non-root user, no privilege escalation
2. **Filesystem protection**: Read-only root, ephemeral tmp
3. **Capability restriction**: All Linux capabilities dropped
4. **Resource limits**: CPU/memory bounds
5. **Network isolation**: Only specific ingress/egress allowed
6. **Syscall filtering**: Seccomp profile applied

## Threat Model

| Threat | Layer 1 | Layer 2 | Layer 3 |
|--------|---------|---------|---------|
| **Container escape** | securityContext (non-root) | capabilities (drop ALL) | seccomp (syscall filtering) |
| **Lateral movement** | Network policies (default-deny) | RBAC (scoped permissions) | mTLS (zero trust) |
| **Privilege escalation** | allowPrivilegeEscalation: false | runAsNonRoot: true | Pod Security Standards |
| **Malware persistence** | readOnlyRootFilesystem: true | emptyDir (ephemeral) | Image scanning |
| **Resource exhaustion** | Resource requests | Resource limits | ResourceQuota |

---

*Defense in depth: assume breach, build redundancy, make attacks expensive.*
