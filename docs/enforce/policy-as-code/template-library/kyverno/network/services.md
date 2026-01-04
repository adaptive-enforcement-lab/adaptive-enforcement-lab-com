---
title: Kyverno Network Service Templates
description: >-
  Enforce Kubernetes Service type restrictions with Kyverno policies controlling LoadBalancer, NodePort, and ExternalName usage to prevent cost overruns and security risks.
tags:
  - kyverno
  - service
  - loadbalancer
  - nodeport
  - network-security
  - kubernetes
  - templates
---
# Kyverno Network Service Templates

Enforces Service type restrictions and configuration standards. Prevents unauthorized LoadBalancers, NodePort exposure, and ExternalName DNS hijacking.

!!! danger "LoadBalancer Services Cost Real Money"
    Each LoadBalancer Service provisions a cloud load balancer. Unrestricted LoadBalancer creation can cost thousands per month. Enforce approval workflows.

---

## Template 5: Service Type Restrictions

Restricts Service types to prevent cost overruns and security risks. Controls LoadBalancer, NodePort, and ExternalName usage.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-service-types
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: block-loadbalancer-without-approval
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
            - istio-system
            - ingress-nginx
          selector:
            matchLabels:
              loadbalancer-approved: "true"
      validate:
        message: >-
          LoadBalancer Services require approval.
          Add label 'loadbalancer-approved: true' after platform team review.
        pattern:
          spec:
            type: "!LoadBalancer"
    - name: restrict-nodeport-range
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
            - monitoring
      validate:
        message: "NodePort services must use ports in range 30000-32767"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.type }}"
                operator: Equals
                value: "NodePort"
              - key: "{{ request.object.spec.ports[].nodePort || `0` }}"
                operator: LessThan
                value: 30000
              - key: "{{ request.object.spec.ports[].nodePort || `0` }}"
                operator: GreaterThan
                value: 32767
    - name: block-nodeport-in-production
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
            - monitoring
          selector:
            matchLabels:
              nodeport-exception: "true"
      validate:
        message: >-
          NodePort Services are prohibited in production namespaces.
          Use Ingress or LoadBalancer instead.
        deny:
          conditions:
            any:
              - key: "{{ request.namespace }}"
                operator: In
                value: ["production", "prod", "prd"]
              - key: "{{ request.object.spec.type }}"
                operator: Equals
                value: "NodePort"
    - name: restrict-externalname-services
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
          selector:
            matchLabels:
              external-dns-approved: "true"
      validate:
        message: >-
          ExternalName Services can be used for DNS hijacking.
          Require 'external-dns-approved: true' label after security review.
        pattern:
          spec:
            type: "!ExternalName"
    - name: enforce-internal-loadbalancer-annotation
      match:
        resources:
          kinds:
            - Service
          selector:
            matchLabels:
              visibility: "private"
      validate:
        message: "Services with 'visibility: private' label must use internal LoadBalancer annotation"
        pattern:
          spec:
            type: LoadBalancer
          metadata:
            annotations:
              (service.beta.kubernetes.io/aws-load-balancer-internal): "true"
              (cloud.google.com/load-balancer-type): "Internal"
              (service.beta.kubernetes.io/azure-load-balancer-internal): "true"
    - name: require-loadbalancer-healthcheck
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
      preconditions:
        any:
          - key: "{{ request.object.spec.type }}"
            operator: Equals
            value: "LoadBalancer"
      validate:
        message: "LoadBalancer Services must define healthCheckNodePort or annotations for health checks"
        deny:
          conditions:
            all:
              - key: "{{ request.object.spec.healthCheckNodePort || `0` }}"
                operator: Equals
                value: 0
              - key: "{{ request.object.metadata.annotations.\"service.beta.kubernetes.io/aws-load-balancer-healthcheck-path\" || '' }}"
                operator: Equals
                value: ""
    - name: block-service-externalips
      match:
        resources:
          kinds:
            - Service
      exclude:
        resources:
          namespaces:
            - kube-system
            - metallb-system
          selector:
            matchLabels:
              external-ip-approved: "true"
      validate:
        message: "Service externalIPs are prohibited. Use LoadBalancer or Ingress instead."
        pattern:
          spec:
            X(externalIPs): null
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `loadbalancer-approval-label` | `loadbalancer-approved: true` | Required label for LoadBalancer services |
| `nodeport-range` | `30000-32767` | Valid NodePort port range |
| `production-namespaces` | `production`, `prod`, `prd` | Namespaces blocking NodePort |
| `externalname-approval-label` | `external-dns-approved: true` | Required for ExternalName services |
| `internal-lb-annotations` | Cloud provider specific | Force internal LoadBalancers |

### Validation Commands

```bash
# Apply policy
kubectl apply -f service-type-restrictions-policy.yaml

# Test ClusterIP service (should pass)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
EOF

# Test LoadBalancer without approval (should fail)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: app-lb-unapproved
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
EOF

# Test LoadBalancer with approval (should pass)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: app-lb-approved
  namespace: default
  labels:
    loadbalancer-approved: "true"
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-healthcheck-path: "/healthz"
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 8080
EOF

# Audit LoadBalancer services
kubectl get services -A -o json | jq -r '.items[] | select(.spec.type == "LoadBalancer") | "\(.metadata.namespace)/\(.metadata.name): \(.metadata.labels.\"loadbalancer-approved\" // "NO-APPROVAL")"'

# Count LoadBalancers per namespace
kubectl get services -A -o json | jq -r '.items | group_by(.metadata.namespace) | .[] | "\(.[0].metadata.namespace): \([.[] | select(.spec.type == "LoadBalancer")] | length) LoadBalancers"'

# Check for NodePort in production
kubectl get services -n production -o json | jq -r '.items[] | select(.spec.type == "NodePort") | "\(.metadata.namespace)/\(.metadata.name)"'

# Audit ExternalName services
kubectl get services -A -o json | jq -r '.items[] | select(.spec.type == "ExternalName") | "\(.metadata.namespace)/\(.metadata.name): \(.spec.externalName)"'

# Check for services with externalIPs
kubectl get services -A -o json | jq -r '.items[] | select(.spec.externalIPs != null) | "\(.metadata.namespace)/\(.metadata.name): \(.spec.externalIPs)"'

# Estimate LoadBalancer costs (AWS example)
kubectl get services -A -o json | jq -r '[.items[] | select(.spec.type == "LoadBalancer")] | length * 20 | "Estimated monthly cost: $\(.) (at $20/month per LB)"'
```

### Use Cases

1. **Cost Control**: Prevent unauthorized cloud load balancer provisioning (can cost $20-50/month each)
2. **Security Boundaries**: Block NodePort exposure in production namespaces
3. **DNS Hijacking Prevention**: Restrict ExternalName services that can redirect internal traffic to attacker-controlled domains
4. **Compliance Requirements**: Enforce internal LoadBalancers for private services
5. **Operational Visibility**: Track LoadBalancer distribution and health check configuration
6. **Migration Safety**: Control Service type changes during application migrations

---

## Related Resources

- **[Kyverno Network Security →](security.md)** - NetworkPolicy and egress requirements
- **[Kyverno Ingress Class →](ingress-class.md)** - IngressClass requirements
- **[Kyverno Ingress TLS →](ingress-tls.md)** - TLS encryption requirements
- **[Kyverno Labels →](../labels.md)** - Mandatory metadata
- **[Kyverno Resource Limits →](../resource/limits.md)** - CPU and memory enforcement
- **[Template Library Overview →](index.md)** - Back to main page
