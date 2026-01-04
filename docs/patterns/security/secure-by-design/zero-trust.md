---
title: Zero Trust Patterns
description: >-
  Zero trust patterns for Kubernetes. Service mesh mTLS, mutual authentication, certificate rotation, and network-level verification.
tags:
  - zero-trust
  - mtls
  - service-mesh
  - security
---
# Zero Trust Patterns

Zero trust rejects implicit trust. Every service, workload, and request proves its identity and intent. The network becomes a verification layer.

## Pattern: Service Mesh mTLS with Certificate Rotation

### Overview

All inter-service communication is encrypted and mutually authenticated using TLS certificates managed automatically by the service mesh control plane. Unencrypted communication is rejected at the sidecar proxy layer.

### Threat Model Addressed

- Man-in-the-middle attacks on pod-to-pod traffic
- Lateral movement without cryptographic proof of identity
- Plaintext credential leakage between services
- Unauthorized service-to-service communication

### Implementation Example

```yaml
# istio/namespace-mtls-policy.yaml
---
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  # Enforce mTLS for all traffic in this namespace
  mtls:
    mode: STRICT
  # Port-level overrides for services that must accept plaintext (legacy services only)
  portLevelMtls:
    8080:
      mode: DISABLE
---
# istio/destination-rule.yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: api-service
  namespace: production
spec:
  host: api-service.production.svc.cluster.local
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL  # Mutual TLS with automatic certificate management
      sni: api-service.production.svc.cluster.local
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        http2MaxRequests: 1000
---
# istio/virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: api-service
  namespace: production
spec:
  hosts:
  - api-service.production.svc.cluster.local
  http:
  - match:
    - sourceLabels:
        version: v2  # Only v2 clients can access this route
    route:
    - destination:
        host: api-service.production.svc.cluster.local
        port:
          number: 8443
      weight: 100
  - route:
    - destination:
        host: api-service.production.svc.cluster.local
        port:
          number: 8443
      weight: 100
```

### Security Properties

- **Encryption in Transit**: All pod-to-pod traffic encrypted with TLS 1.2+
- **Mutual Authentication**: Each side verifies the other's identity via X.509 certificate
- **Automatic Certificate Rotation**: Control plane rotates certificates before expiry (default: 24h)
- **Certificate Authority Boundary**: Each namespace can have its own CA or shared organizational CA
- **Sidecar Enforcement**: Proxy intercepts all outbound connections; plaintext attempts fail

!!! warning "PERMISSIVE Mode Defeats Zero Trust"
    `PERMISSIVE` mode accepts both mTLS and plaintext traffic. This creates a downgrade attack vector. Use `STRICT` mode in production. No exceptions.

### Anti-Patterns to Avoid

- **Not enforcing STRICT mode**: Using `PERMISSIVE` mode in production leaves a window for plaintext traffic
- **Ignoring certificate expiry**: Rotated certificates must match application certificate pinning if used
- **Mixing encrypted and plaintext services**: Services without sidecars bypass the security model entirely
- **Port-level exceptions without justification**: Every plaintext exception should have a deprecation plan

### Verification

```bash
# Check mTLS policy enforcement
kubectl get peerauthentication -A

# Verify sidecar injection
kubectl get pods -A -o jsonpath='{.items[*].spec.containers[*].name}' | grep istio-proxy

# Monitor TLS failures
kubectl logs -n istio-system -l app=istiod | grep tls
```

## Related Patterns

- **[Defense in Depth](defense-in-depth.md)** - Layer multiple controls
- **[Fail Secure](fail-secure.md)** - Default to denial
- **[Integration](integration.md)** - Combine all patterns

---

*Zero trust means proving every claim. mTLS provides cryptographic proof of identity at the network layer.*
