---
description: >-
  Enterprise supply chain security and multi-tenancy policies using JMESPath. Image signing, digest pinning, vulnerability scanning, and tenant isolation.
tags:
  - kyverno
  - jmespath
  - supply-chain-security
  - multi-tenancy
  - kubernetes
---

# Enterprise Supply Chain & Multi-Tenancy

Advanced JMESPath patterns for supply chain security and multi-tenant isolation. Enforce image signing, digest pinning, vulnerability gates, and tenant isolation policies.

!!! abstract "TL;DR"
    Supply chain security policies verify image integrity and provenance. Multi-tenancy policies enforce isolation between tenants in shared clusters.

---

## Image Supply Chain Security

Enforce image signing, digest pinning, and vulnerability scanning.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: supply-chain-security
spec:
  validationFailureAction: enforce
  background: false
  rules:
    - name: require-image-digests
      match:
        resources:
          kinds:
            - Pod
            - Deployment
          namespaces:
            - prod-*
      validate:
        message: "Production images must be pinned to digest (image@sha256:...)"
        foreach:
          - list: "request.object.spec.template.spec.containers[] || request.object.spec.containers[]"
            deny:
              conditions:
                any:
                  - key: "{{ element.image | contains(@, '@sha256:') }}"
                    operator: Equals
                    value: false

    - name: require-signature-verification
      match:
        resources:
          kinds:
            - Pod
            - Deployment
          namespaces:
            - prod-*
      validate:
        message: "Images must be signed (cosign annotation required)"
        deny:
          conditions:
            all:
              - key: "{{ request.object.metadata.annotations.\"cosign.sigstore.dev/signature\" || '' }}"
                operator: Equals
                value: ""

    - name: block-high-severity-cves
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "Images with HIGH or CRITICAL CVEs are blocked"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.annotations.\"scan.aquasec.com/severity\" || '' }}"
                operator: In
                value: ["HIGH", "CRITICAL"]
```

### Use Cases

- SLSA supply chain compliance
- Image vulnerability enforcement
- Cosign/Sigstore signature verification
- Container registry security gates

---

## Multi-Tenancy Isolation

Enforce tenant isolation with namespace-based validation.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: multi-tenancy-isolation
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: restrict-namespace-label-matching
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "workload label must match namespace tenant label"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.labels.tenant || '' }}"
                operator: NotEquals
                value: "{{ request.namespace.metadata.labels.tenant || '' }}"

    - name: prevent-host-namespace-access
      match:
        resources:
          kinds:
            - Pod
            - Deployment
      validate:
        message: "Host namespaces (PID, IPC, network) are forbidden in multi-tenant clusters"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.hostPID || `false` }}"
                operator: Equals
                value: true
              - key: "{{ request.object.spec.template.spec.hostIPC || `false` }}"
                operator: Equals
                value: true
              - key: "{{ request.object.spec.template.spec.hostNetwork || `false` }}"
                operator: Equals
                value: true
```

### Use Cases

- SaaS multi-tenant Kubernetes clusters
- Team isolation in shared clusters
- Compliance with tenant data separation
- Prevent cross-tenant resource access

---

## Related Resources

- **[JMESPath Enterprise Examples →](enterprise.md)** - Registry validation, cost allocation, HA requirements
- **[JMESPath Testing →](testing.md)** - Test these policies before deployment
- **[JMESPath Reference →](reference.md)** - Complete function reference
- **[JMESPath Advanced →](advanced.md)** - Advanced patterns
- **[JMESPath Patterns (Core) →](patterns.md)** - Core patterns
- **[Kyverno Templates Overview →](../kyverno-templates.md)** - Complete template library
- **[Template Library Overview →](index.md)** - Back to main page

---

## External References

- [Kyverno Policy Library](https://kyverno.io/policies/)
- [CNCF Security TAG Policies](https://github.com/cncf/tag-security/tree/main/policy)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NIST SP 800-190 (Container Security)](https://csrc.nist.gov/publications/detail/sp/800-190/final)
- [SLSA Framework](https://slsa.dev/)
- [Sigstore Cosign](https://docs.sigstore.dev/cosign/overview/)
