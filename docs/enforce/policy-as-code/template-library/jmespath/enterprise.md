---
title: Enterprise JMESPath Policy Examples
description: >-
  Enterprise JMESPath policy examples for Kyverno. Registry validation, cost allocation, high availability requirements, and production-ready patterns.
tags:
  - kyverno
  - jmespath
  - policy-as-code
  - kubernetes
  - enterprise
---
# Enterprise JMESPath Policy Examples

Real-world enterprise Kyverno policies using advanced JMESPath. Production-tested patterns for registry validation, cost allocation, and compliance.

!!! abstract "TL;DR"
    Enterprise policies combine multiple JMESPath patterns to enforce organizational standards. These examples are production-ready and customizable.

---

## Enterprise Registry Validation

Enforce approved registries across environments with region-specific requirements.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enterprise-registry-validation
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-production-registry
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
          namespaces:
            - prod-*
      validate:
        message: "Production must use enterprise registry (prod.acme.io or prod-dr.acme.io)"
        foreach:
          - list: "request.object.spec.template.spec.containers[] || request.object.spec.containers[]"
            deny:
              conditions:
                any:
                  - key: "{{ element.image | split(@, '/')[0] }}"
                    operator: NotIn
                    value: ["prod.acme.io", "prod-dr.acme.io"]

    - name: validate-staging-registry
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
          namespaces:
            - staging-*
      validate:
        message: "Staging must use staging registry (staging.acme.io)"
        foreach:
          - list: "request.object.spec.template.spec.containers[] || request.object.spec.containers[]"
            deny:
              conditions:
                any:
                  - key: "{{ element.image | split(@, '/')[0] }}"
                    operator: NotEquals
                    value: "staging.acme.io"
```

### Customization

```yaml
# Adjust approved registries per environment
value: ["prod.acme.io", "prod-dr.acme.io", "prod.backup.acme.io"]

# Add exception namespaces
match:
  resources:
    namespaces:
      - prod-*
    exclude:
      namespaces:
        - prod-testing
```

---

## Cost Allocation Enforcement

Enforce cost center labels and validate format for chargeback systems.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: cost-allocation-labels
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: require-cost-labels
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
            - CronJob
            - Job
      validate:
        message: "Resources must have cost-center and team labels"
        pattern:
          metadata:
            labels:
              cost-center: "?*"
              team: "?*"
              environment: "dev | staging | prod"

    - name: validate-cost-center-format
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
      validate:
        message: "cost-center must be 4-digit number (e.g., 1234)"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.labels.\"cost-center\" | length(@) }}"
                operator: NotEquals
                value: 4

    - name: validate-team-against-namespace
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
      validate:
        message: "team label must match namespace prefix"
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.labels.team || '' }}"
                operator: NotEquals
                value: "{{ request.namespace | split(@, '-')[0] }}"
```

### Use Cases

- Kubernetes cost allocation for chargebacks
- Resource tagging for cloud cost management
- Compliance reporting and auditing
- Multi-tenant cluster cost tracking

---

## High Availability Requirements

Enforce HA standards based on criticality labels.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: ha-requirements
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: critical-services-need-ha
      match:
        resources:
          kinds:
            - Deployment
      validate:
        message: "Critical services must have >= 3 replicas"
        deny:
          conditions:
            all:
              - key: "{{ request.object.metadata.labels.criticality || '' }}"
                operator: In
                value: ["high", "critical"]
              - key: "{{ request.object.spec.replicas || `1` }}"
                operator: LessThan
                value: 3

    - name: require-pdb-for-critical
      match:
        resources:
          kinds:
            - Deployment
      validate:
        message: "Critical deployments must have PodDisruptionBudget annotation"
        deny:
          conditions:
            all:
              - key: "{{ request.object.metadata.labels.criticality || '' }}"
                operator: Equals
                value: "critical"
              - key: "{{ request.object.metadata.annotations.\"pdb.kubernetes.io/created\" || '' }}"
                operator: Equals
                value: ""

    - name: anti-affinity-for-ha
      match:
        resources:
          kinds:
            - Deployment
      validate:
        message: "HA deployments must use pod anti-affinity"
        deny:
          conditions:
            all:
              - key: "{{ request.object.metadata.labels.tier || '' }}"
                operator: Equals
                value: "high"
              - key: "{{ request.object.spec.replicas || `1` }}"
                operator: GreaterThanOrEquals
                value: 3
              - key: "{{ request.object.spec.template.spec.affinity.podAntiAffinity || '' }}"
                operator: Equals
                value: ""
```

### Use Cases

- Enforce SLA-based replica requirements
- Prevent single points of failure
- Compliance with availability standards
- Production readiness gates

---

## Security Compliance Policies

Multi-layer security validation for compliance frameworks.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: security-compliance
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: pci-dss-container-requirements
      match:
        resources:
          kinds:
            - Pod
            - Deployment
          namespaces:
            - pci-*
      validate:
        message: "PCI-DSS requires non-root, read-only filesystem, dropped capabilities"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[?!securityContext.runAsNonRoot] | length(@) }}"
                operator: GreaterThan
                value: 0
              - key: "{{ request.object.spec.template.spec.containers[?!securityContext.readOnlyRootFilesystem] | length(@) }}"
                operator: GreaterThan
                value: 0
              - key: "{{ request.object.spec.template.spec.containers[?!securityContext.capabilities.drop] | length(@) }}"
                operator: GreaterThan
                value: 0

    - name: hipaa-sensitive-data-labels
      match:
        resources:
          kinds:
            - Deployment
            - StatefulSet
          namespaces:
            - health-*
      validate:
        message: "HIPAA workloads must have data-classification label"
        pattern:
          metadata:
            labels:
              data-classification: "phi | pii | public"

    - name: sox-audit-trail-required
      match:
        resources:
          kinds:
            - Deployment
          namespaces:
            - finance-*
      validate:
        message: "SOX workloads must have audit logging enabled"
        pattern:
          metadata:
            annotations:
              audit.logging.enabled: "true"
              audit.retention.days: "?*"
```

### Use Cases

- PCI-DSS container security requirements
- HIPAA data classification enforcement
- SOX audit trail compliance
- FedRAMP security controls

---

## Related Resources

- **[Enterprise Supply Chain & Multi-Tenancy →](enterprise-supply-chain.md)** - Image signing, vulnerability scanning, tenant isolation
- **[JMESPath Testing →](testing.md)** - Test these policies before deployment
- **[JMESPath Reference →](reference.md)** - Complete function reference
- **[JMESPath Advanced →](advanced.md)** - Advanced patterns
- **[JMESPath Patterns (Core) →](patterns.md)** - Core patterns
- **[Kyverno Templates Overview →](../kyverno/index.md)** - Complete template library
- **[Template Library Overview →](index.md)** - Back to main page

---

## External References

- [Kyverno Policy Library](https://kyverno.io/policies/)
- [CNCF Security TAG Policies](https://github.com/cncf/tag-security/tree/main/policy)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NIST SP 800-190 (Container Security)](https://csrc.nist.gov/publications/detail/sp/800-190/final)
