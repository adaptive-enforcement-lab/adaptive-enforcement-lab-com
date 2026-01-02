---
description: >-
  Production-ready Kyverno and OPA policy templates. Pod security, image validation, resource limits, namespace isolation, and CI/CD integration patterns for policy-as-code enforcement.
tags:
  - policy-as-code
  - kyverno
  - opa
  - kubernetes
  - templates
---

# Production-Ready Policy Templates

Complete, battle-tested policy templates for Kyverno and OPA/Gatekeeper. Copy, customize, deploy.

<!-- more -->

!!! abstract "Template Library Overview"
    This library contains production-grade policies covering pod security, image validation, resource management, namespace isolation, and CI/CD integration. Each template includes full YAML, customization variables, validation commands, and real-world use cases.

## Overview

This library contains production-grade policies covering:

- **Pod Security**: Privilege escalation prevention, capability restrictions, read-only filesystems
- **Image Validation**: Registry allowlists, signature verification, base image requirements
- **Resource Management**: CPU/memory limits, requests, quota enforcement
- **Namespace Isolation**: Network policies, RBAC constraints, resource quotas
- **CI/CD Integration**: Pre-commit validation, GitHub Actions automation, ArgoCD gating

Each template includes full YAML, customization variables, validation commands, and real-world use cases.

---

## Template Categories

### [Kyverno Templates →](kyverno-templates.md)

Production-ready Kyverno policies for Kubernetes admission control:

- Pod security standards enforcement
- Image validation and registry allowlists
- Resource limits and requests enforcement
- Mandatory labels and annotations

### [OPA/Gatekeeper Templates →](opa-templates.md)

OPA Gatekeeper constraint templates for policy-driven infrastructure:

- Namespace isolation and network policy enforcement
- Cross-namespace access controls
- Custom resource validation

### [CI/CD Integration →](ci-cd-integration.md)

Automated policy validation in development pipelines:

- GitHub Actions pre-flight validation
- ArgoCD policy gating
- Pre-commit hooks

### [Usage Guide →](usage-guide.md)

Template customization workflow, validation best practices, and quick start guides:

- Customization workflow
- Validation best practices
- Quick start guides
- Troubleshooting

---

## Quick Start

### Minimal Setup (5 minutes)

```bash
# 1. Install Kyverno
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno --namespace kyverno --create-namespace

# 2. Apply pod-security policy
kubectl apply -f kyverno-templates.md

# 3. Test it works
kubectl run test --image=nginx  # Should fail: no resource limits
kubectl run test --image=nginx --requests=cpu=100m,memory=128Mi --limits=cpu=500m,memory=512Mi  # Should pass
```

### Production Deployment (Infrastructure as Code)

```bash
# 1. Create policy namespace
kubectl create namespace policy-enforcement

# 2. Apply all policies
kubectl apply -f policies/ -n policy-enforcement

# 3. Configure cluster-wide enforcement
kubectl patch clusterpolicy restrict-privileged-containers -p '{"spec":{"validationFailureAction":"enforce"}}'

# 4. Monitor violations
kubectl logs -n policy-enforcement -f deployment/kyverno
```

---

## Next Steps

- Review [Kyverno Best Practices](https://kyverno.io/docs/writing-policies/best-practices/)
- Explore [OPA/Gatekeeper Documentation](https://open-policy-agent.org/docs/latest/kubernetes-admission-control/)
- Join [Kyverno Community](https://kyverno.io/community/)
- Set up [Policy Testing Pipeline](https://kyverno.io/docs/testing-policies/)
