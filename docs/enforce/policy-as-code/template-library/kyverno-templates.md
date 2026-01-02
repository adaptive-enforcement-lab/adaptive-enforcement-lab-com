---
description: >-
  Kyverno policy templates overview. Production-ready policies for pod security, image validation, resource limits, and mandatory labels.
tags:
  - kyverno
  - kubernetes
  - policy-as-code
  - templates
---

# Kyverno Policy Templates

!!! warning "Start with Audit Mode"
    Deploy in `audit` mode first. Existing workloads may violate these policies. Monitor violations for 48 hours, fix non-compliant pods, then switch to `enforce`.

Production-ready Kyverno policies for Kubernetes admission control. Each template includes complete configuration, customization options, validation commands, and real-world use cases.

---

## Available Templates

### Pod Security

Enforce pod security standards, prevent privileged containers, require read-only root filesystems, and drop dangerous capabilities.

**[View Pod Security Templates →](kyverno-pod-security.md)**

Key features:

- Restrict privileged containers
- Drop all capabilities
- Enforce read-only root filesystems
- Require non-root users

---

### Image Validation

Control which container images can be deployed with registry allowlists, tag validation, and signature verification.

**[View Image Validation Templates →](kyverno-image-validation.md)**

Key features:

- Registry allowlists
- Prohibit `latest` tags
- Block untrusted registries
- Support image signature verification

---

### Resource Limits

Ensure all workloads define CPU and memory requests and limits to prevent resource exhaustion.

**[View Resource Limits Templates →](kyverno-resource-limits.md)**

Key features:

- Require resource requests and limits
- Enforce resource ranges
- Validate init containers
- Prevent resource starvation

---

### Mandatory Labels

Enforce required metadata for observability, cost tracking, and compliance auditing.

**[View Mandatory Labels Templates →](kyverno-labels.md)**

Key features:

- Require app, team, version labels
- Enforce environment labels
- Validate label formats
- Require observability annotations

---

## Quick Start

All templates follow the same deployment pattern:

```bash
# Apply policy in audit mode first
kubectl apply -f policy.yaml

# Monitor policy violations
kubectl logs -f -n kyverno deployment/kyverno

# Switch to enforce mode after validation
kubectl patch clusterpolicy <policy-name> \
  --type merge \
  -p '{"spec":{"validationFailureAction":"enforce"}}'
```

## Related Resources

- **[OPA Templates →](opa-templates.md)** - Gatekeeper constraint templates
- **[CI/CD Integration →](ci-cd-integration.md)** - Automated policy validation
- **[Usage Guide →](usage-guide.md)** - Customization and troubleshooting
- **[Template Library Overview →](index.md)** - Back to main page
