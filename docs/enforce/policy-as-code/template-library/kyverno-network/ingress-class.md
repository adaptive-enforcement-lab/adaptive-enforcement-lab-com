---
description: >-
  Enforce approved Ingress classes with Kyverno policies ensuring production workloads use standardized controllers and blocking deprecated configurations.
tags:
  - kyverno
  - ingress
  - ingressclass
  - network-security
  - kubernetes
  - templates
---

# Kyverno Ingress Class Templates

Enforces Ingress controller standards. Ensures production workloads use approved ingress classes and prevents deprecated annotation usage.

!!! warning "IngressClass Standardization Required"
    Without IngressClass enforcement, teams can deploy arbitrary ingress controllers, creating security and operational inconsistencies.

---

## Template 3: Ingress Class Requirements

Enforces use of approved IngressClass resources. Prevents deployment of Ingress objects using unknown or deprecated controllers.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-ingress-class
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-ingressclass-exists
      match:
        resources:
          kinds:
            - Ingress
      exclude:
        resources:
          namespaces:
            - kube-system
      validate:
        message: "Ingress must specify an ingressClassName from the approved list"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.ingressClassName || '' }}"
                operator: Equals
                value: ""
    - name: validate-approved-ingressclass
      match:
        resources:
          kinds:
            - Ingress
      exclude:
        resources:
          namespaces:
            - kube-system
            - local-dev
      validate:
        message: "Only approved IngressClasses are allowed: nginx, nginx-internal, traefik, istio"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.ingressClassName }}"
                operator: NotIn
                value: ["nginx", "nginx-internal", "traefik", "istio"]
    - name: enforce-internal-ingressclass-for-private
      match:
        resources:
          kinds:
            - Ingress
          selector:
            matchLabels:
              visibility: "private"
      validate:
        message: "Private ingress resources must use nginx-internal or traefik-internal"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.ingressClassName }}"
                operator: NotIn
                value: ["nginx-internal", "traefik-internal", "istio-internal"]
    - name: block-deprecated-ingress-annotations
      match:
        resources:
          kinds:
            - Ingress
      validate:
        message: "Deprecated 'kubernetes.io/ingress.class' annotation must not be used. Use spec.ingressClassName instead."
        deny:
          conditions:
            any:
              - key: "{{ request.object.metadata.annotations.\"kubernetes.io/ingress.class\" || '' }}"
                operator: NotEquals
                value: ""
    - name: require-ingress-hostname
      match:
        resources:
          kinds:
            - Ingress
      exclude:
        resources:
          namespaces:
            - kube-system
      validate:
        message: "Ingress must define at least one host in spec.rules[].host"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.rules[].host || `[]` }}"
                operator: Equals
                value: []
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `approved-ingressclasses` | `nginx`, `nginx-internal`, `traefik`, `istio` | Permitted ingress controllers |
| `internal-ingressclasses` | `nginx-internal`, `traefik-internal` | Controllers for private endpoints |
| `validationFailureAction` | `enforce` | Use `audit` before enforcement |
| `require-hostname` | `true` | Block wildcard-only ingress rules |

### Validation Commands

```bash
# Apply policy
kubectl apply -f ingress-class-policy.yaml

# List available IngressClasses
kubectl get ingressclass

# Test ingress with approved class (should pass)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
EOF

# Test ingress without class (should fail)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress-fail
  namespace: default
spec:
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: app-service
                port:
                  number: 80
EOF

# Audit ingress resources using deprecated annotations
kubectl get ingress -A -o json | jq -r '.items[] | select(.metadata.annotations["kubernetes.io/ingress.class"] != null) | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.annotations["kubernetes.io/ingress.class"])"'

# Check for ingress without hostnames
kubectl get ingress -A -o json | jq -r '.items[] | select(.spec.rules[].host == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Audit IngressClass distribution
kubectl get ingress -A -o json | jq -r '.items | group_by(.spec.ingressClassName) | .[] | "\(.[0].spec.ingressClassName): \(length) ingress resources"'
```

### Use Cases

1. **Controller Standardization**: Enforce organizational standards for ingress controllers
2. **Security Boundaries**: Separate public and private ingress traffic flows
3. **Migration Management**: Block deprecated annotation usage during controller upgrades
4. **Multi-tenant Isolation**: Restrict ingress controller access by namespace or team
5. **Cost Control**: Prevent use of expensive cloud load balancers without approval

---

## Related Resources

- **[Kyverno Ingress TLS →](ingress-tls.md)** - TLS encryption requirements
- **[Kyverno Network Security →](security.md)** - NetworkPolicy and egress requirements
- **[Kyverno Network Services →](services.md)** - Service type restrictions
- **[Kyverno Labels →](../kyverno-labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
