---
description: >-
  Enforce TLS encryption on all Ingress resources with Kyverno policies preventing cleartext HTTP traffic and ensuring cert-manager integration.
tags:
  - kyverno
  - ingress
  - tls
  - encryption
  - cert-manager
  - network-security
  - kubernetes
  - templates
---

# Kyverno Ingress TLS Templates

Enforces TLS encryption requirements for Ingress resources. Ensures production workloads use HTTPS with valid certificates and automated renewal.

!!! danger "HTTP Ingress Exposes Unencrypted Traffic"
    Ingress without TLS sends credentials and data in plaintext. Enforce TLS on all production ingress resources.

---

## Template 4: Ingress TLS Requirements

Enforces TLS encryption on all Ingress resources in production namespaces. Prevents cleartext HTTP traffic to production applications.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-ingress-tls
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-tls-configuration
      match:
        resources:
          kinds:
            - Ingress
      exclude:
        resources:
          namespaces:
            - kube-system
            - local-dev
            - dev
            - test
      validate:
        message: "Ingress in production namespaces must define TLS configuration"
        pattern:
          spec:
            tls:
              - hosts:
                  - "?*"
                secretName: "?*"
    - name: validate-tls-secret-exists
      match:
        resources:
          kinds:
            - Ingress
      exclude:
        resources:
          namespaces:
            - kube-system
            - local-dev
      context:
        - name: tlsSecrets
          apiCall:
            urlPath: "/api/v1/namespaces/{{ request.namespace }}/secrets"
            jmesPath: "items[?type=='kubernetes.io/tls'].metadata.name"
      validate:
        message: "TLS secret referenced in Ingress must exist as type kubernetes.io/tls"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.tls[].secretName }}"
                operator: AnyNotIn
                value: "{{ tlsSecrets }}"
    - name: enforce-tls-hostname-match
      match:
        resources:
          kinds:
            - Ingress
      exclude:
        resources:
          namespaces:
            - kube-system
      validate:
        message: "TLS hosts must match at least one rule host"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.tls[].hosts[] }}"
                operator: AnyNotIn
                value: "{{ request.object.spec.rules[].host }}"
    - name: block-http-redirect-annotation-removal
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
        message: "Production ingress must include SSL redirect annotation"
        pattern:
          metadata:
            annotations:
              (nginx.ingress.kubernetes.io/ssl-redirect): "true"
    - name: require-cert-manager-annotation
      match:
        resources:
          kinds:
            - Ingress
      exclude:
        resources:
          namespaces:
            - kube-system
          selector:
            matchLabels:
              cert-manager.io/issuer: "manual"
      validate:
        message: "Ingress must specify cert-manager.io/cluster-issuer for automated certificate management"
        pattern:
          metadata:
            annotations:
              cert-manager.io/cluster-issuer: "?*"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `production-namespaces` | All except `dev`, `test`, `local-dev` | Namespaces requiring TLS |
| `validationFailureAction` | `enforce` | Use `audit` for gradual rollout |
| `cert-manager-issuer` | Required unless `manual` label present | Automated certificate provisioning |
| `ssl-redirect` | `true` | Force HTTP to HTTPS redirection |

### Validation Commands

```bash
# Apply policy
kubectl apply -f ingress-tls-policy.yaml

# Create TLS secret
kubectl create secret tls app-tls-secret \
  --cert=./tls.crt \
  --key=./tls.key \
  -n default

# Test ingress with TLS (should pass)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress-tls
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls-secret
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

# Test ingress without TLS in production (should fail)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress-no-tls
  namespace: production
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

# Audit ingress without TLS
kubectl get ingress -A -o json | jq -r '.items[] | select(.spec.tls == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check TLS secret types
kubectl get secrets -A -o json | jq -r '.items[] | select(.metadata.name | endswith("-tls")) | "\(.metadata.namespace)/\(.metadata.name): \(.type)"'

# Audit cert-manager coverage
kubectl get ingress -A -o json | jq -r '.items[] | select(.metadata.annotations["cert-manager.io/cluster-issuer"] == null) | "\(.metadata.namespace)/\(.metadata.name)"'

# Check for expired certificates
kubectl get secrets -A -o json | jq -r '.items[] | select(.type == "kubernetes.io/tls") | "\(.metadata.namespace)/\(.metadata.name): \(.data."tls.crt" | @base64d)"' | openssl x509 -noout -enddate
```

### Use Cases

1. **Encryption in Transit**: Prevent credential and data exposure via unencrypted HTTP
2. **PCI-DSS Compliance**: Enforce TLS for all cardholder data transmission
3. **Certificate Management**: Ensure automated certificate renewal via cert-manager
4. **Security Auditing**: Track TLS configuration and certificate expiration
5. **HTTPS Enforcement**: Block accidental deployment of HTTP-only ingress resources

---

## Related Resources

- **[Kyverno Ingress Class →](ingress-class.md)** - IngressClass requirements
- **[Kyverno Network Security →](security.md)** - NetworkPolicy and egress requirements
- **[Kyverno Network Services →](services.md)** - Service type restrictions
- **[Kyverno Labels →](../labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
