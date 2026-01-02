---
title: Admission Controllers
description: Enforce security policies with Kubernetes ValidatingAdmissionPolicy controllers, blocking privileged containers and invalid configurations before deployment.
---

# Admission Controllers

Admission controllers enforce policies on incoming API requests before objects are persisted.

!!! abstract "Policy Enforcement"

    Admission controllers block invalid manifests before deployment. This prevents misconfigurations from reaching production.

## Custom Resource Policy

```yaml
# admission-controllers/validation-policy.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: container-security-policy
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(container, !has(container.securityContext) || !container.securityContext.privileged)"
      message: "Privileged containers are not allowed"

    - expression: "object.spec.containers.all(container, !has(container.securityContext) || container.securityContext.runAsNonRoot == true)"
      message: "Containers must run as non-root"

    - expression: "object.spec.containers.all(container, !has(container.securityContext) || !container.securityContext.allowPrivilegeEscalation)"
      message: "Privilege escalation is not allowed"

    - expression: "object.spec.containers.all(container, has(container.resources.limits.cpu) && has(container.resources.limits.memory))"
      message: "All containers must define CPU and memory limits"

    - expression: "object.spec.containers.all(container, container.imagePullPolicy == 'Always')"
      message: "All containers must use imagePullPolicy: Always"

---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: container-security-policy-binding
spec:
  policyName: container-security-policy
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels:
        enforce-policy: "true"
```

!!! note "Namespace Selection"

    Apply policies to specific namespaces using labels. Production namespaces should have `enforce-policy: "true"`.

## Deployment

```bash
# Apply admission policies
kubectl apply -f admission-controllers/

# Verify policy is installed
kubectl get validatingadmissionpolicies

# Test policy (should fail)
kubectl run test --image=nginx --namespace=prod
# Error: Containers must run as non-root
```

## Verification Checklist

```bash
#!/bin/bash
# Admission policy verification

echo "=== Admission Policies ==="
kubectl get validatingadmissionpolicies --no-headers 2>/dev/null | wc -l | \
  awk '{if ($1 > 0) print "✓ Admission policies deployed ("$1")"; else print "✗ No admission policies"}'
```

## Related Content

- **[Pod Security Standards](pod-security-standards.md)** - Namespace-level security policies
- **[Runtime Monitoring](runtime-monitoring.md)** - Behavioral analysis and alerting
- **[Cluster Configuration](../cluster-configuration/binary-authorization.md)** - Binary Authorization

## References

- [Admission Controllers](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- [Validating Admission Policy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
