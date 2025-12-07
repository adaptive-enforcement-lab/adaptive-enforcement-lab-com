---
title: Kyverno Policy Patterns
description: >-
  Common validation and mutation patterns: image provenance, required labels, resource limits,
  privilege escalation prevention, and automatic security configurations.
---

# Kyverno Policy Patterns

Production-tested policy patterns for Kubernetes admission control. These patterns enforce security, compliance, and operational standards at the cluster boundary.

!!! note "Policy Enforcement"
    Start policies in Audit mode before switching to Enforce to avoid breaking production deployments.

---

## Image Provenance

Only allow images from approved registries:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: Enforce
  rules:
    - name: validate-registries
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Images must come from gcr.io or pkg.dev registries"
        pattern:
          spec:
            containers:
              - image: "gcr.io/* | *.pkg.dev/*"
```

Blocks Docker Hub, public registries, unverified sources.

### Multi-Registry Pattern

```yaml
validate:
  message: "Images must come from approved registries"
  pattern:
    spec:
      containers:
        - image: "gcr.io/* | *.pkg.dev/* | ghcr.io/your-org/*"
```

---

## Required Labels

Enforce labeling standards for cost allocation and observability:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-labels
      match:
        any:
          - resources:
              kinds:
                - Deployment
                - StatefulSet
                - DaemonSet
      validate:
        message: "Required labels: team, environment, cost-center"
        pattern:
          metadata:
            labels:
              team: "?*"
              environment: "production | staging | development"
              cost-center: "?*"
```

No cost-center label? Deployment fails.

**Pattern explanation:**

- `"?*"` = Any non-empty value
- `"production | staging | development"` = Allowed enum values
- Missing label triggers validation failure

---

## Mutation Policies

Kyverno can also modify resources automatically:

### Auto-Generate Network Policies

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-network-policy
spec:
  rules:
    - name: add-network-policy
      match:
        any:
          - resources:
              kinds:
                - Namespace
      generate:
        kind: NetworkPolicy
        name: default-deny
        namespace: "{{request.object.metadata.name}}"
        data:
          spec:
            podSelector: {}
            policyTypes:
              - Ingress
              - Egress
```

Every new namespace automatically gets a default-deny network policy. Security by default.

### Inject Sidecar Containers

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: inject-sidecar
spec:
  rules:
    - name: add-sidecar
      match:
        any:
          - resources:
              kinds:
                - Deployment
              selector:
                matchLabels:
                  inject-sidecar: "true"
      mutate:
        patchStrategicMerge:
          spec:
            template:
              spec:
                containers:
                  - name: logging-sidecar
                    image: fluent/fluent-bit:latest
                    volumeMounts:
                      - name: logs
                        mountPath: /var/log
```

---

## Production Patterns

### Prevent Privilege Escalation

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-privilege-escalation
spec:
  validationFailureAction: Enforce
  rules:
    - name: deny-privilege-escalation
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Privilege escalation is not allowed"
        pattern:
          spec:
            containers:
              - securityContext:
                  allowPrivilegeEscalation: false
```

### Block Host Namespaces

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-host-namespaces
spec:
  validationFailureAction: Enforce
  rules:
    - name: deny-host-namespaces
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Host namespaces are not allowed"
        pattern:
          spec:
            =(hostNetwork): false
            =(hostPID): false
            =(hostIPC): false
```

**Pattern:** `=(key): value` = Deny if key exists with different value.

### Enforce Read-Only Root Filesystem

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-ro-rootfs
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-ro-rootfs
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Root filesystem must be read-only"
        pattern:
          spec:
            containers:
              - securityContext:
                  readOnlyRootFilesystem: true
```

### Block Latest Tag

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  rules:
    - name: require-image-tag
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Image tag 'latest' is not allowed"
        pattern:
          spec:
            containers:
              - image: "!*:latest"
```

**Pattern:** `!*:latest` = NOT ending with `:latest`.

---

## Policy Composition

Combine multiple checks in one policy:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pod-security-standards
spec:
  validationFailureAction: Enforce
  rules:
    - name: security-context
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Pod security standards violated"
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
              fsGroup: ">0"
            containers:
              - securityContext:
                  allowPrivilegeEscalation: false
                  readOnlyRootFilesystem: true
                  runAsNonRoot: true
                  capabilities:
                    drop:
                      - ALL
```

Multiple security requirements enforced atomically.

---

## Real-World Policy Set

From production clusters:

```yaml
# 1. Image security
- restrict-image-registries
- disallow-latest-tag
- require-image-signature  # Sigstore/Cosign integration

# 2. Resource management
- require-resource-limits
- require-resource-requests
- enforce-pdb  # Pod Disruption Budgets

# 3. Security posture
- restrict-privilege-escalation
- require-ro-rootfs
- restrict-host-namespaces
- drop-all-capabilities

# 4. Operational standards
- require-labels
- require-probes  # Liveness/readiness
- add-default-network-policy

# 5. Compliance
- require-pod-security-standard
- enforce-pod-anti-affinity
- restrict-node-selection
```

---

## Related Guides

- **[Kyverno Basics](index.md)** - Installation and audit/enforce modes
- **[Testing and Exceptions](testing-approaches.md)** - Test policies before enforcement
- **[CI/CD Integration](ci-cd-integration.md)** - End-to-end policy enforcement

---

*Image from Docker Hub blocked. Deployment without resource limits rejected. Privileged container denied. Network policy generated automatically. Policies enforced. Production secured.*
