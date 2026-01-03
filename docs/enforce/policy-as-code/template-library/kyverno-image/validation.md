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

## Template 1: Image Digest Requirements

Enforces SHA256 digest references instead of mutable tags. Digest-based references ensure immutable deployments and prevent tag-based image substitution attacks.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-digest
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: check-image-digest
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
        message: "Container images must use digest references (SHA256), not tags"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - image: "*@sha256:*"
                initContainers?:
                  - image: "*@sha256:*"
                ephemeralContainers?:
                  - image: "*@sha256:*"
    - name: deny-tag-only-references
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
        message: "Tag-only image references are not allowed. Use digest format: image@sha256:..."
        deny:
          conditions:
            any:
              - key: "{{ request.object.spec.template.spec.containers[].image || request.object.spec.containers[].image }}"
                operator: AnyNotIn
                value: ["*@sha256:*"]
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for gradual rollout |
| `digest-algorithm` | `sha256` | Cryptographic hash algorithm |
| `exclude-namespaces` | None | Exempt development namespaces |
| `allow-tag-with-digest` | `false` | Allow `image:tag@sha256:...` format |

### Validation Commands

```bash
# Apply policy
kubectl apply -f digest-requirements-policy.yaml

# Test with tag only (should fail)
kubectl run test --image=nginx:1.21 -n default --dry-run=client -o yaml | kubectl apply -f -

# Test with digest (should pass)
kubectl run test --image=nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603 -n default --dry-run=client -o yaml | kubectl apply -f -

# Get digest for an image
docker pull nginx:1.21
docker inspect nginx:1.21 --format='{{.RepoDigests}}'

# Convert tag to digest in deployment
kubectl get deployment web -o yaml | sed 's/:latest/@sha256:abc123.../' | kubectl apply -f -
```

### Use Cases

1. **Immutable Deployments**: Prevent silent image updates when tags are overwritten
2. **Supply Chain Security**: Ensure exact image version deployed matches security scans
3. **Compliance Auditing**: Track precise image versions for regulatory requirements
4. **Rollback Safety**: Reference exact image versions for reliable rollbacks
5. **Image Signing**: Required for verifying cryptographic signatures (cosign, notary)

### Converting Tags to Digests

Generate digest references from tags:

```bash
# Get digest for a tagged image
skopeo inspect docker://nginx:1.21 | jq -r '.Digest'

# Update deployment with digest
IMAGE_DIGEST=$(skopeo inspect docker://nginx:1.21 | jq -r '.Digest')
kubectl set image deployment/web nginx=nginx@${IMAGE_DIGEST}

# Validate all images in namespace use digests
kubectl get pods -n production -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | grep -v "@sha256:"
```

---

## Template 2: Registry Allowlist and Tag Validation

Controls which container images can be deployed. Enforces registry allowlists, prohibits `latest` tags, and validates image sources.

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

- **[Kyverno Image Signing →](signing.md)** - Cosign signature verification
- **[Kyverno Image Security →](security.md)** - Base image enforcement and CVE gates
- **[Kyverno Pod Security →](../kyverno-pod-security.md)** - Security contexts and capabilities
- **[Kyverno Resource Limits →](../kyverno-resource-limits.md)** - CPU and memory enforcement
- **[Kyverno Labels →](../kyverno-labels.md)** - Mandatory metadata
- **[Template Library Overview →](../index.md)** - Back to main page
