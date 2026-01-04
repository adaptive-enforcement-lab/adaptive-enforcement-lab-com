---
title: Kyverno Network Security Templates
description: >-
  Enforce Kubernetes network policies and egress restrictions with Kyverno policies preventing lateral movement and data exfiltration.
tags:
  - kyverno
  - network-security
  - network-policy
  - egress
  - kubernetes
  - templates
---
# Kyverno Network Security Templates

Enforces network isolation through NetworkPolicy requirements and egress restrictions. Prevents lateral movement and unauthorized external communication.

!!! danger "No Network Policies Equals Flat Network"
    Without NetworkPolicies, all pods can communicate with all other pods. Default-deny network policies are the foundation of zero-trust networking.

---

## Template 1: Require Network Policies

Ensures all namespaces have NetworkPolicy objects defined. Prevents deployment of workloads into namespaces without network segmentation controls.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-network-policy
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-namespace-has-networkpolicy
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
            - kube-node-lease
      preconditions:
        all:
          - key: "{{ request.operation }}"
            operator: In
            value: ["CREATE", "UPDATE"]
      validate:
        message: >-
          Namespace must have at least one NetworkPolicy before deploying workloads.
          Create a default-deny policy first.
        deny:
          conditions:
            any:
              - key: "{{ networkPolicyCount('{{ request.namespace }}') }}"
                operator: LessThan
                value: 1
    - name: require-default-deny-ingress
      match:
        resources:
          kinds:
            - Namespace
      exclude:
        resources:
          names:
            - kube-system
            - kube-public
            - kube-node-lease
            - default
      validate:
        message: "New namespaces must include a default-deny ingress NetworkPolicy"
        pattern:
          metadata:
            annotations:
              network-policy.kubernetes.io/default-deny: "true"
    - name: validate-pod-network-policy-labels
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
      validate:
        message: "Pods must have 'app' label for NetworkPolicy pod selectors"
        pattern:
          spec:
            (template)?:
              metadata:
                labels:
                  app: "?*"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for gradual rollout |
| `minimum-networkpolicies` | `1` | Require at least one NetworkPolicy per namespace |
| `exclude-namespaces` | System namespaces | Exempt kube-system and monitoring tools |
| `required-pod-labels` | `app` | Label required for NetworkPolicy selectors |

### Validation Commands

```bash
# Apply policy
kubectl apply -f require-network-policy.yaml

# Create namespace with default-deny annotation
kubectl create namespace test-ns
kubectl annotate namespace test-ns network-policy.kubernetes.io/default-deny="true"

# Create default-deny NetworkPolicy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: test-ns
spec:
  podSelector: {}
  policyTypes:
    - Ingress
EOF

# Test deployment (should pass after NetworkPolicy exists)
kubectl create deployment nginx --image=nginx -n test-ns

# Audit namespaces without NetworkPolicies
kubectl get namespaces -o json | jq -r '.items[] | select(.metadata.name != "kube-system" and .metadata.name != "kube-public") | .metadata.name' | while read ns; do
  count=$(kubectl get networkpolicies -n $ns --no-headers 2>/dev/null | wc -l)
  if [ $count -eq 0 ]; then
    echo "WARNING: Namespace $ns has no NetworkPolicies"
  fi
done

# List all NetworkPolicies
kubectl get networkpolicies -A

# Check NetworkPolicy coverage
kubectl get pods -A -o json | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.labels.app // "NO-APP-LABEL")"'
```

### Use Cases

1. **Zero Trust Networking**: Enforce network segmentation as a prerequisite for workload deployment
2. **Multi-tenant Isolation**: Prevent cross-namespace communication without explicit NetworkPolicies
3. **PCI-DSS Compliance**: Enforce network isolation for cardholder data environments
4. **Lateral Movement Prevention**: Block attackers from pivoting between compromised pods
5. **Compliance Auditing**: Ensure all production namespaces have documented network policies

---

## Template 2: Egress Restrictions

Restricts outbound network traffic to approved destinations. Prevents data exfiltration and unauthorized external API calls.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-egress-traffic
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: require-egress-policy
      match:
        resources:
          kinds:
            - NetworkPolicy
      exclude:
        resources:
          namespaces:
            - kube-system
            - kube-public
      validate:
        message: "NetworkPolicies with egress rules must specify explicit destinations"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.policyTypes[?@ == 'Egress'] || `[]` }}"
                operator: NotEquals
                value: []
              - key: "{{ request.object.spec.egress || `[]` }}"
                operator: Equals
                value: []
    - name: block-unrestricted-egress
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
      exclude:
        resources:
          namespaces:
            - kube-system
            - istio-system
          selector:
            matchLabels:
              network-policy.kubernetes.io/egress: "unrestricted"
      validate:
        message: >-
          Pods in production namespaces must not have unrestricted egress.
          Add 'network-policy.kubernetes.io/egress: unrestricted' label for exceptions.
        deny:
          conditions:
            any:
              - key: "{{ request.namespace }}"
                operator: In
                value: ["production", "prod", "prd"]
    - name: require-dns-only-egress
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
      exclude:
        resources:
          selector:
            matchLabels:
              network-egress: "external"
      validate:
        message: "Pods without 'network-egress: external' label must only allow DNS egress"
        pattern:
          metadata:
            annotations:
              egress-destinations: "dns-only"
    - name: block-external-ips
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
            - metallb-system
            - istio-system
      validate:
        message: "Services with externalIPs are prohibited. Use LoadBalancer or Ingress instead."
        pattern:
          spec:
            X(externalIPs): null
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for initial deployment |
| `production-namespaces` | `production`, `prod`, `prd` | Namespaces requiring strict egress controls |
| `egress-exception-label` | `network-policy.kubernetes.io/egress: unrestricted` | Opt-out for specific workloads |
| `allowed-external-cidrs` | Cloud provider IPs | Permitted external destinations |

### Validation Commands

```bash
# Apply policy
kubectl apply -f egress-restrictions-policy.yaml

# Create egress NetworkPolicy allowing only DNS
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
EOF

# Create egress NetworkPolicy for specific external API
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: api-client
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 203.0.113.0/24
      ports:
        - protocol: TCP
          port: 443
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
EOF

# Test pod with network-egress label
kubectl run test --image=nginx -n default --labels="network-egress=external"

# Audit NetworkPolicies without egress rules
kubectl get networkpolicies -A -o json | jq -r '.items[] | select(.spec.policyTypes[] == "Egress" and (.spec.egress | length) == 0) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check for Services with externalIPs
kubectl get services -A -o json | jq -r '.items[] | select(.spec.externalIPs != null) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.externalIPs)"'

# Monitor egress traffic (requires CNI plugin support)
kubectl logs -n kube-system -l k8s-app=calico-node | grep EGRESS
```

### Use Cases

1. **Data Exfiltration Prevention**: Block unauthorized outbound connections to prevent data theft
2. **Supply Chain Security**: Restrict container runtime network access to known-good registries
3. **Compliance Requirements**: Enforce network boundaries for SOC2, ISO 27001, HIPAA
4. **Cost Control**: Prevent excessive egress bandwidth charges from misconfigured applications
5. **Incident Containment**: Limit blast radius of compromised workloads attempting C2 communication

---

## Related Resources

- **[Kyverno Ingress Class →](ingress-class.md)** - IngressClass requirements
- **[Kyverno Ingress TLS →](ingress-tls.md)** - TLS encryption requirements
- **[Kyverno Network Services →](services.md)** - Service type restrictions
- **[Kyverno Pod Security →](../pod-security/standards.md)** - Security contexts and capabilities
- **[Kyverno Labels →](../labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
