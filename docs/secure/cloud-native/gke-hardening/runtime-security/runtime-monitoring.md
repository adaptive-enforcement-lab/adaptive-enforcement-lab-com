---
title: Runtime Monitoring
description: Deploy Falco for runtime behavioral analysis to detect unauthorized process execution, file access violations, and anomalous network activity in workloads.
---

# Runtime Monitoring

Monitor pod behavior at runtime using Falco or GKE Cloud Logging.

!!! warning "Behavioral Detection"

    Runtime monitoring detects anomalous behavior like unexpected process execution, file access, or network connections.

## Falco Configuration (Optional)

```yaml
# falco/values.yaml
falco:
  grpc:
    enabled: true
  grpcOutput:
    enabled: true

falcoctl:
  artifact:
    follow:
      enabled: true

rules:
  - https://download.falco.org/rules/falco-rules.yaml
  - https://download.falco.org/rules/container-runtime-rules.yaml

customRules:
  rules-custom.yaml: |
    - rule: Unauthorized Process
      desc: Detect unauthorized process execution
      condition: >
        spawned_process and
        container and
        not proc.name in (nginx, postgres, redis, node, python, java)
      output: >
        Unauthorized process (%proc.name)
        spawned in container (%container.id)
        by user (%user.name)
      priority: WARNING

    - rule: Sensitive File Access
      desc: Detect access to sensitive files
      condition: >
        open_read and
        container and
        (fd.name startswith /etc/shadow or
         fd.name startswith /etc/passwd or
         fd.name contains .ssh/id_rsa)
      output: >
        Sensitive file accessed (%fd.name)
        in container (%container.id)
        by process (%proc.name)
      priority: CRITICAL
```

## Deployment

```bash
# Add Falco Helm repository
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

# Install Falco
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --values falco/values.yaml

# Verify Falco is running
kubectl get pods -n falco

# Check Falco logs
kubectl logs -n falco -l app.kubernetes.io/name=falco
```

!!! tip "Integration with SIEM"

    Forward Falco alerts to your SIEM (Splunk, ELK, Chronicle) for centralized security monitoring.

## Deployment Workflow

### 1. Deploy Admission Controllers

```bash
# Apply admission policies
kubectl apply -f admission-controllers/

# Verify policy
kubectl get validatingadmissionpolicies
kubectl get validatingadmissionpolicybindings
```

### 2. Install Runtime Monitoring

```bash
# Deploy Falco
helm install falco falcosecurity/falco \
  --namespace falco \
  --create-namespace \
  --values falco/values.yaml

# Verify installation
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=falco -n falco --timeout=300s
```

## Runtime Security Checklist

```bash
#!/bin/bash
# Runtime monitoring verification

echo "=== Runtime Monitoring ==="
kubectl get pods -n falco --no-headers 2>/dev/null | wc -l | \
  awk '{if ($1 > 0) print "✓ Falco deployed"; else print "✗ No runtime monitoring"}'
```

## Related Content

- **[Pod Security Standards](pod-security-standards.md)** - Namespace-level security policies
- **[Admission Controllers](admission-controllers.md)** - Pre-deployment validation
- **[Cluster Configuration](../cluster-configuration/index.md)** - Private GKE cluster setup

## References

- [Falco Runtime Security](https://falco.org/docs/)
- [GKE Security Bulletins](https://cloud.google.com/kubernetes-engine/docs/security-bulletins)
- [Cloud Logging](https://cloud.google.com/logging/docs)
