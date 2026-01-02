---
description: >-
  OPA Gatekeeper templates for Kubernetes policy enforcement. Namespace isolation, network policies, and custom resource validation with complete Rego code and constraint examples.
tags:
  - opa
  - gatekeeper
  - kubernetes
  - policy-as-code
---

# OPA/Gatekeeper Policy Templates

OPA Gatekeeper constraint templates for advanced policy enforcement. Complete Rego implementations with constraint examples and network policy integration.

---

## Template: Namespace Isolation and Network Policy Enforcement

!!! warning "Network Policies Require CNI Support"
    Not all Kubernetes CNIs support network policies. Verify your CNI (Calico, Cilium, Weave) supports NetworkPolicy before deploying. Without CNI support, policies are silently ignored.

Prevents workloads in different namespaces from communicating without explicit network policies.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8snetworkpolicyrequired
spec:
  crd:
    spec:
      names:
        kind: K8sNetworkPolicyRequired
      validation:
        openAPIV3Schema:
          properties:
            namespaces:
              type: array
              items:
                type: string
              description: "Namespaces where network policy is required"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8snetworkpolicyrequired

        violation[{"msg": msg}] {
            input.review.kind.kind == "Deployment"
            namespace := input.review.object.metadata.namespace
            some i
            namespace == input.parameters.namespaces[i]
            pod_selector := input.review.object.spec.selector.matchLabels

            count(pod_selector) == 0
            msg := sprintf(
              "Namespace %v requires workloads to have labels for network policy selection",
              [namespace]
            )
        }

        violation[{"msg": msg}] {
            input.review.kind.kind == "Namespace"
            ns_name := input.review.object.metadata.name
            some i
            ns_name == input.parameters.namespaces[i]

            has_labels := object.get(input.review.object, "metadata", {}).labels
            has_labels == null
            msg := sprintf(
              "Namespace %v requires labels for network policy enforcement",
              [ns_name]
            )
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sNetworkPolicyRequired
metadata:
  name: namespace-network-policy-required
spec:
  parameters:
    namespaces:
      - production
      - staging
      - shared-services
  match:
    namespaceSelector:
      matchLabels:
        enforce-network-policy: "true"
    excludedNamespaces:
      - kube-system
      - kube-public
      - kube-node-lease
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: frontend
      ports:
        - protocol: TCP
          port: 8080
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-database
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: api
      ports:
        - protocol: TCP
          port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-ingress
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 443
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `enforce-namespaces` | `production`, `staging`, `shared-services` | List namespaces requiring policies |
| `default-deny` | All ingress denied unless allowed | Implicit security posture |
| `tier-labels` | `frontend`, `api`, `database` | Define your application tiers |
| `excluded-namespaces` | System namespaces | Don't enforce on cluster infrastructure |

### Validation Commands

```bash
# Apply OPA templates and constraints
kubectl apply -f namespace-network-policy.yaml

# Verify constraint template installation
kubectl get constrainttemplates
kubectl get constraints

# Test namespace with network policies enabled
kubectl label namespace production enforce-network-policy=true

# Test deployment without pod selector labels (should fail)
kubectl run test --image=nginx -n production

# Test with proper labels (should pass)
kubectl run test --image=nginx -n production --labels=tier=frontend

# Verify default deny is working
kubectl -n production exec <pod> -- curl <other-pod-ip>  # Should timeout

# Check network policy status
kubectl get networkpolicies -n production
kubectl describe networkpolicy allow-frontend-to-api -n production

# Verify traffic flow
kubectl -n production exec <frontend-pod> -- curl http://<api-pod>:8080
```

### Use Cases

1. **Zero-Trust Network Security**: Default deny with explicit allow rules
2. **Compliance Requirements**: Demonstrate network segmentation in audits
3. **Multi-tenant Isolation**: Prevent accidental cross-tenant communication
4. **Blast Radius Limitation**: Contain compromised workloads
5. **Regulatory Compliance**: PCI-DSS and HIPAA require network isolation

---

## Related Resources

- **[Kyverno Templates →](kyverno-templates.md)** - Kubernetes-native policies
- **[CI/CD Integration →](ci-cd-integration.md)** - Automated policy validation
- **[Usage Guide →](usage-guide.md)** - Customization and troubleshooting
- **[Template Library Overview →](index.md)** - Back to main page
