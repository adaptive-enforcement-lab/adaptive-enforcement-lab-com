---
title: Network Policies
description: Implement zero-trust Kubernetes network policies with default-deny ingress rules, explicit pod-to-pod traffic control, and granular egress filtering patterns.
---

# Network Policies

Kubernetes Network Policies restrict traffic between pods and from external sources. By default, GKE allows all ingress and egress traffic.

!!! warning "Default-Deny Required"

    Implement a default-deny ingress policy and explicitly allow traffic between services. This is a zero-trust network model.

## Manifest Example

```yaml
# network-policies/default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: apps
spec:
  podSelector: {}
  policyTypes:
    - Ingress

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: apps
spec:
  podSelector:
    matchLabels:
      tier: backend
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
  name: allow-backend-to-database
  namespace: apps
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
              tier: backend
      ports:
        - protocol: TCP
          port: 5432

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: apps
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api-egress
  namespace: apps
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 443
```

!!! note "Policy Scope"

    Network policies apply per-namespace. Create them in each namespace where workloads run.

## Deployment

```bash
# Apply network policies
kubectl apply -f network-policies/

# Verify policies
kubectl get networkpolicies -n apps

# Test connectivity (should fail for pods without policy)
kubectl run test-pod --image=busybox -n apps -- sleep 3600
kubectl exec test-pod -n apps -- wget -O- http://my-app:8080
# Expected: Connection refused (due to default-deny)
```

!!! danger "Testing Before Production"

    Always test network policies in QAC/DEV first. Incorrect policies can break legitimate traffic.

## Network Security Checklist

```bash
#!/bin/bash
# Network policy verification

CLUSTER="prod-cluster"
REGION="us-central1"

echo "=== Network Policies ==="
kubectl get networkpolicies --all-namespaces \
  --no-headers 2>/dev/null | wc -l | \
  awk '{if ($1 > 0) print "✓ Network policies deployed ("$1")"; else print "✗ No network policies"}'
```

## Related Content

- **[VPC-Native Networking](vpc-native.md)** - Container-native IP allocation
- **[Private Service Connect](private-service-connect.md)** - Secure GCP service access
- **[Cloud Armor](cloud-armor.md)** - DDoS protection and WAF
