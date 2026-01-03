---
description: >-
  Migration strategies for OPA and Kyverno. Migrate from Kyverno to OPA, supplement OPA with Kyverno, or run hybrid deployments. Policy translation examples and phased rollout guides.
tags:
  - policy-as-code
  - kyverno
  - opa
  - gatekeeper
  - migration
---

# OPA/Kyverno Migration Strategies

Migration paths between OPA and Kyverno. Phased rollout strategies, policy translation examples, and hybrid deployment patterns.

!!! tip "Read the Decision Guide First"
    Before migrating, read the [Decision Guide](decision-guide.md) to understand which approach fits your requirements.

---

## Migration Paths Overview

| Starting Point | Migration Target | Timeline | Risk Level |
|----------------|------------------|----------|------------|
| **Kyverno → OPA** | Full migration | 2-4 months | Medium |
| **OPA → Kyverno** | Supplement (hybrid) | 2-4 weeks | Low |
| **None → Hybrid** | Deploy both | 1-2 months | Medium |

---

## Kyverno to OPA Migration

### When to Migrate

Migrate from Kyverno to OPA when:

- Policy scope expands beyond Kubernetes (Terraform, APIs)
- Kyverno's JMESPath hits complexity limits
- Team grows policy expertise and needs advanced features
- External data integration becomes critical

### Migration Strategy

Phase your migration to minimize disruption.

#### Phase 1: Run Both in Parallel (2-4 weeks)

1. Deploy Gatekeeper alongside Kyverno
2. Run both in audit mode
3. Compare violation reports for consistency
4. Build team expertise with Rego

#### Phase 2: Translate Policies (4-8 weeks)

1. Start with simplest policies (label requirements)
2. Rewrite in Rego using constraint templates
3. Test with `opa test` framework
4. Deploy OPA policies in audit mode
5. Validate behavior matches Kyverno

#### Phase 3: Switch Enforcement (2-4 weeks)

1. Enable OPA enforcement one policy at a time
2. Disable corresponding Kyverno policy
3. Monitor for 48 hours before proceeding
4. Document any behavioral differences

#### Phase 4: Decommission Kyverno (1-2 weeks)

1. Verify all policies migrated
2. Run final audit comparison
3. Remove Kyverno policies
4. Uninstall Kyverno operator

---

### Policy Translation Examples

#### Label Requirement

Kyverno uses pattern matching:

```yaml
validate:
  pattern:
    metadata:
      labels:
        team: "?*"
```

OPA uses Rego logic:

```rego
violation[{"msg": msg}] {
  not input.review.object.metadata.labels.team
  msg := "Team label is required"
}
```

#### Image Registry Allowlist

Kyverno pattern:

```yaml
validate:
  pattern:
    spec:
      containers:
        - image: "registry.example.com/*"
```

OPA Rego:

```rego
violation[{"msg": msg}] {
  container := input.review.object.spec.containers[_]
  not startswith(container.image, "registry.example.com/")
  msg := sprintf("Image %v not from approved registry", [container.image])
}
```

!!! tip "Full Examples"
    See [Kyverno Templates](kyverno/index.md) and [OPA Templates](opa/index.md) for complete policy definitions.

---

## OPA Supplemented with Kyverno

### When to Supplement

Add Kyverno to an existing OPA deployment when:

- You need image signature verification (Cosign)
- You want resource generation (network policies, quotas)
- You need mutation capabilities

### Hybrid Strategy

Define clear boundaries between engines.

**OPA Handles:**

- Complex compliance logic
- Multi-platform policies
- Cross-resource validation
- External data integration

**Kyverno Handles:**

- Image signature verification
- Resource mutation
- Resource generation
- Simple validation

---

### Hybrid Deployment Example

Kyverno handles image signatures:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-images
spec:
  validationFailureAction: enforce
  rules:
    - name: verify-cosign
      match:
        resources:
          kinds: [Pod]
      verifyImages:
        - image: "registry.example.com/*"
          attestors:
            - entries:
              - keys:
                  publicKeys: |-
                    -----BEGIN PUBLIC KEY-----
                    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE...
                    -----END PUBLIC KEY-----
```

OPA handles time-based compliance:

```rego
package kubernetes.admission

deny[msg] {
  input.request.kind.kind == "Deployment"
  input.request.object.metadata.namespace == "production"
  not is_recently_approved(input.request.object)
  msg := "Production requires approval within 7 days"
}

is_recently_approved(deployment) {
  deployment.metadata.labels["approved-by"]
  deployment.metadata.labels["scan-date"]
  scan_time := time.parse_rfc3339_ns(deployment.metadata.labels["scan-date"])
  time.now_ns() - scan_time < 604800000000000  # 7 days
}
```

---

## Hybrid Deployment Best Practices

### Policy Ownership

Document which engine owns which policy types:

| Policy Type | Engine | Rationale |
|-------------|--------|-----------|
| **Image verification** | Kyverno | Built-in Cosign support |
| **Label validation** | Kyverno | Simple YAML patterns |
| **Time-based compliance** | OPA | Complex date logic |
| **Cross-namespace rules** | OPA | Rego query capabilities |
| **Resource generation** | Kyverno | Native generation support |
| **External data** | OPA | HTTP data sources |

---

### Conflict Prevention

#### Most Restrictive Wins

If both engines validate the same resource, both must pass. The more restrictive policy takes precedence.

#### Single Source of Truth

Each policy type should be owned by one engine only. Don't duplicate validation logic.

Avoid this conflict:

```yaml
# Kyverno: requires team, environment
# OPA: requires team, owner
# CONFLICT: inconsistent requirements
```

Instead, choose one engine for label validation:

```yaml
# Kyverno owns ALL label validation
require: [team, environment, owner]
```

---

## Testing Strategy

Test both engines in parallel:

```bash
# Test Kyverno policies
kyverno test --policy-dir policies/kyverno

# Test OPA policies
opa test policies/opa --explain=full

# Integration test
kubectl apply --dry-run=server -f test-deployment.yaml
```

---

## Migration Checklist

Pre-migration:

- [ ] Backup existing policies
- [ ] Document current violation patterns
- [ ] Establish rollback procedures

During migration:

- [ ] Run both engines in audit mode
- [ ] Compare violation reports
- [ ] Test policy translations
- [ ] Monitor admission latency

Post-migration:

- [ ] All policies migrated
- [ ] No increase in false positives
- [ ] Team trained on new tooling
- [ ] Documentation updated

---

## Next Steps

- **[Decision Guide →](decision-guide.md)** - Framework for choosing between OPA and Kyverno
- **[Detailed Comparison →](opa-kyverno-comparison.md)** - Capability and ecosystem comparison
- **[Kyverno Templates →](kyverno/index.md)** - Ready-to-use Kyverno policies
- **[OPA Templates →](opa/index.md)** - OPA constraint templates
- **[Usage Guide →](usage-guide.md)** - Customization workflow
- **[Template Library Overview →](index.md)** - Back to main page

---

## External References

- [Kyverno Documentation](https://kyverno.io/docs/)
- [OPA/Gatekeeper Documentation](https://open-policy-agent.org/docs/latest/kubernetes-introduction/)
- [Kyverno Testing Guide](https://kyverno.io/docs/testing-policies/)
- [OPA Testing Guide](https://www.openpolicyagent.org/docs/latest/policy-testing/)
- [Gatekeeper Constraint Templates](https://open-policy-agent.github.io/gatekeeper-library/website/)
