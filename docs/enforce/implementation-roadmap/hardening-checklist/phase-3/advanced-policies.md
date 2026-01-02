---
description: >-
  Advanced runtime policies. Namespace resource quotas, pod security standards, network policy enforcement, and comprehensive Kubernetes security controls.
tags:
  - kyverno
  - pod-security
  - network-policy
  - resource-quotas
  - kubernetes
---

# Phase 3: Advanced Runtime Policies

Extend runtime enforcement with namespace quotas, pod security standards, and network policies.

---

## Namespace Resource Quotas

!!! warning "Start with Audit Mode"
    Deploy resource quotas in audit mode first. Existing workloads may exceed new limits, blocking deployments. Monitor violations for 48 hours before enforcing.

### Cluster-Wide Resource Limits

Enforce cluster-wide resource limits by namespace:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-namespace-quota
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-quota
      match:
        resources:
          kinds: [Namespace]
      validate:
        message: "Namespace must have ResourceQuota"
        pattern:
          metadata:
            name: "!kube-*"
        deny:
          conditions:
            - key: "{{request.object.metadata.name}}"
              operator: NotIn
              value: ["kube-system", "kyverno"]
```

Deploy quota policy:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-resources
  namespace: production
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
```

---

## Pod Security Standards

!!! tip "Namespace-Level Enforcement"
    Pod Security Standards can be scoped by namespace. Start with `baseline` for dev environments, `restricted` for production. This gradual approach reduces friction.

### Baseline and Restricted Standards

Enforce baseline or restricted pod security standards:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-pod-security
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: restricted
      match:
        any:
          - resources:
              kinds:
                - Pod
              namespaces:
                - production
      validate:
        podSecurity:
          level: restricted
          version: latest
```

---

## Network Policy Enforcement

!!! warning "Default-Deny Breaks Everything"
    Network policies are default-allow until you create one. The first policy creates a default-deny posture. Test in staging first. DNS, monitoring, and logging will break without explicit egress rules.

### Required Network Policies

Require network policies for all namespaces:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-network-policy
spec:
  validationFailureAction: Audit  # Start with Audit, move to Enforce
  background: true
  rules:
    - name: check-network-policy
      match:
        resources:
          kinds: [Namespace]
      validate:
        message: "Namespace must have NetworkPolicy defined"
        deny:
          conditions:
            - key: "{{request.object.metadata.name}}"
              operator: AnyNotIn
              value: ["kube-system", "kyverno"]
```

---

## Related Patterns

- **[Policy Enforcement](policy-enforcement.md)** - Core runtime policies
- **[Policy Rollout Strategy](rollout.md)** - Deployment approach
- **[Phase 3 Overview →](index.md)** - Runtime phase summary

---

*Namespace quotas enforced. Pod security standards required. Network policies mandatory.*
