---
description: >-
  Enforce container image registry allowlists and prohibit latest tags using Kyverno policies for supply chain security and container signature verification.
tags:
  - kyverno
  - image-validation
  - kubernetes
  - templates
---

# Kyverno Image Validation Templates

Controls which container images can be deployed. Enforces registry allowlists, prohibits `latest` tags, and optionally requires image signatures.

!!! tip "Supply Chain Security First Line"
    Image validation policies are your first defense against supply chain attacks. Block untrusted registries before compromised images reach production.

---

## Template 2: Image Validation and Registry Allowlist

Controls which container images can be deployed. Enforces registry allowlists, prohibits `latest` tags, and optionally requires image signatures.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: allowed-registries
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: validate-registry
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      validate:
        message: "Image registry must be from approved list: registry.example.com, ghcr.io"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - image: "registry.example.com/* | ghcr.io/*"
                initContainers?:
                  - image: "registry.example.com/* | ghcr.io/*"
                ephemeralContainers?:
                  - image: "registry.example.com/* | ghcr.io/*"
    - name: validate-image-tag
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      validate:
        message: "Image tag must be specified and cannot be 'latest'"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - image: "*/[a-zA-Z0-9:_-]*"
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[0].image }}"
                operator: EndsWith
                value: ":latest"
              - key: "{{ request.object.spec.template.spec.containers[0].image }}"
                operator: NotContains
                value: ":"
    - name: restrict-untrusted-registries
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
          excludeResources:
            namespaces:
              - kube-system
              - kube-public
      validate:
        message: "Images from public Docker Hub are not allowed. Use private registry or approved mirrors."
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[0].image }}"
                operator: NotContains
                value: "/"
              - key: "{{ request.object.spec.template.spec.containers[0].image }}"
                operator: HasValue
                value: true
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - image: "*/*:*"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `allowed-registries` | `registry.example.com`, `ghcr.io` | Add your private registry URLs |
| `forbidden-public-registries` | Docker Hub (implicit) | Block public registries |
| `exclude-namespaces` | `kube-system`, `kube-public` | Exempt system namespaces |
| `require-digest` | Optional | Enforce SHA256 digest instead of tags |

### Validation Commands

```bash
# Apply policy
kubectl apply -f image-validation-policy.yaml

# Test with disallowed registry (should fail)
kubectl run test --image=ubuntu:22.04 -n default --dry-run=client -o yaml | kubectl apply -f -

# Test with allowed registry (should pass)
kubectl run test --image=registry.example.com/apps/web:v1.2.3 -n default --dry-run=client -o yaml | kubectl apply -f -

# Check image policy violations
kubectl logs -n kyverno deployment/kyverno | grep "allowed-registries"

# Audit all images currently in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | sort | uniq
```

### Use Cases

1. **Supply Chain Security**: Ensure all images come from verified registries with known SBOMs
2. **Cost Control**: Block expensive public images, force internal mirrors
3. **Compliance Requirements**: Only use images from certified registries (FedRAMP, SOC 2)
4. **Image Signature Verification**: Extend to verify container signatures using Cosign
5. **Multi-region Deployments**: Route images to regional mirrors based on policy

---

## Related Resources

- **[Kyverno Pod Security →](kyverno-pod-security.md)** - Security contexts and capabilities
- **[Kyverno Resource Limits →](kyverno-resource-limits.md)** - CPU and memory enforcement
- **[Kyverno Labels →](kyverno-labels.md)** - Mandatory metadata
- **[Template Library Overview →](index.md)** - Back to main page
