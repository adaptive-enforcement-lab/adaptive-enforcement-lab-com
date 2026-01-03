---
description: >-
  OPA Gatekeeper image digest enforcement. Require SHA256 digest references for immutable deployments and supply chain security.
tags:
  - opa
  - gatekeeper
  - image-security
  - digest
  - kubernetes
  - templates
---

# OPA Image Digest Templates

Enforces SHA256 digest references instead of mutable tags. Digest-based references ensure immutable deployments and prevent tag-based image substitution attacks.

!!! danger "Tags Are Mutable = Security Risk"
    Container image tags can be overwritten in registries, allowing attackers to replace legitimate images. Digest references (`@sha256:...`) are cryptographically immutable and required for signature verification.

---

## Template 3: Digest Enforcement

Requires all container images use SHA256 digest references. Blocks tag-only references to ensure immutable deployments.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8srequireimagedigest
spec:
  crd:
    spec:
      names:
        kind: K8sRequireImageDigest
      validation:
        openAPIV3Schema:
          properties:
            exemptImages:
              type: array
              items:
                type: string
              description: "Images exempt from digest requirement"
            allowTagWithDigest:
              type: boolean
              description: "Allow image:tag@sha256:... format"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequireimagedigest

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not exempt_image(container.image)
          not has_digest(container.image)
          msg := sprintf("Container %v must use digest reference: %v. Use format: image@sha256:...",
            [container.name, container.image])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          not exempt_image(container.image)
          not input.parameters.allowTagWithDigest
          has_tag_and_digest(container.image)
          msg := sprintf("Container %v uses tag+digest format which is not allowed: %v. Use digest-only: image@sha256:...",
            [container.name, container.image])
        }

        has_digest(image) {
          contains(image, "@sha256:")
        }

        has_tag_and_digest(image) {
          contains(image, ":")
          contains(image, "@sha256:")
          # Ensure it's not just sha256 (has both : and @)
          split_parts := split(image, "@")
          contains(split_parts[0], ":")
        }

        exempt_image(image) {
          exempt := input.parameters.exemptImages[_]
          startswith(image, exempt)
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.ephemeralContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequireImageDigest
metadata:
  name: require-image-digest
spec:
  enforcementAction: deny
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet", "DaemonSet"]
      - apiGroups: ["batch"]
        kinds: ["Job", "CronJob"]
    excludedNamespaces:
      - kube-system
  parameters:
    exemptImages: []
    allowTagWithDigest: false  # Set to true to allow image:tag@sha256:... format
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `exemptImages` | `[]` | Images exempt from digest requirement |
| `allowTagWithDigest` | `false` | Allow `image:tag@sha256:...` format |
| `enforcementAction` | `deny` | Use `dryrun` for gradual rollout |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-digest-enforcement.yaml

# Verify installation
kubectl get constrainttemplates k8srequireimagedigest
kubectl get k8srequireimagedigest

# Test with tag only (should fail)
kubectl run test --image=nginx:1.21.6

# Test with digest (should pass)
kubectl run test --image=nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603

# Test with tag+digest (behavior depends on allowTagWithDigest)
kubectl run test --image=nginx:1.21@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603

# Get digest for an image
docker pull nginx:1.21.6
docker inspect nginx:1.21.6 --format='{{index .RepoDigests 0}}'

# Alternative using crane
crane digest nginx:1.21.6

# Alternative using skopeo
skopeo inspect docker://nginx:1.21.6 | jq -r '.Digest'

# Audit images without digests
kubectl get pods -A -o json | jq -r '
  .items[] |
  .spec.containers[] |
  select(.image | contains("@sha256:") | not) |
  "\(.image)"
' | sort | uniq
```

### Use Cases

1. **Immutable Deployments**: Guarantee exact image version deployed never changes
2. **Supply Chain Security**: Required for verifying cryptographic signatures (cosign)
3. **Compliance Auditing**: Prove exact image versions for SOC2/FedRAMP audits
4. **Rollback Safety**: Reference precise image versions for reliable rollbacks
5. **CVE Tracking**: Map deployed digests to vulnerability scan results

---

## Converting Tags to Digests

### Manual Conversion

```bash
# Get digest for a tagged image
IMAGE_TAG="nginx:1.21.6"
IMAGE_DIGEST=$(crane digest ${IMAGE_TAG})
echo "${IMAGE_TAG%:*}@${IMAGE_DIGEST}"

# Update deployment with digest
kubectl set image deployment/web nginx=nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603
```

### Automated Conversion in CI/CD

```yaml
# GitHub Actions workflow
name: Convert to Digest

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install crane
        run: |
          curl -sL https://github.com/google/go-containerregistry/releases/download/v0.15.2/go-containerregistry_Linux_x86_64.tar.gz | tar xz -C /usr/local/bin crane

      - name: Convert manifest to use digests
        run: |
          # Extract image tag from deployment
          IMAGE_TAG=$(yq '.spec.template.spec.containers[0].image' k8s/deployment.yaml)

          # Get digest
          IMAGE_DIGEST=$(crane digest ${IMAGE_TAG})
          IMAGE_BASE=$(echo ${IMAGE_TAG} | cut -d: -f1)

          # Update deployment with digest
          yq -i ".spec.template.spec.containers[0].image = \"${IMAGE_BASE}@${IMAGE_DIGEST}\"" k8s/deployment.yaml

      - name: Deploy to Kubernetes
        run: |
          kubectl apply -f k8s/deployment.yaml
```

### Kyverno Mutation Alternative

If you prefer automatic conversion, consider using Kyverno's mutation policies:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: convert-tag-to-digest
spec:
  rules:
    - name: convert-to-digest
      match:
        resources:
          kinds:
            - Deployment
      mutate:
        foreach:
          - list: "request.object.spec.template.spec.containers"
            patchStrategicMerge:
              spec:
                template:
                  spec:
                    containers:
                      - name: "{{ element.name }}"
                        image: "{{ images.containers.{{ element.name }}.registry }}/{{ images.containers.{{ element.name }}.path }}@{{ images.containers.{{ element.name }}.digest }}"
```

---

## Digest Pinning Best Practices

### Why Digest-Only (Not Tag+Digest)

```yaml
# GOOD: Digest-only reference
image: nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603

# ACCEPTABLE: Tag+digest (if allowTagWithDigest: true)
image: nginx:1.21@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603

# BAD: Tag-only (mutable)
image: nginx:1.21
```

**Digest-only advantages**:

- Clearer that deployment is immutable
- Prevents confusion about which takes precedence
- Required by some signature verification tools
- Simpler to audit and validate

**Tag+digest use cases**:

- Human-readable version in manifests
- Easier debugging and troubleshooting
- Gradual migration from tag-based workflows

### Digest Rotation Strategy

```bash
# Create digest-pinned deployment
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  annotations:
    image-tag: "nginx:1.21.6"  # Document original tag for reference
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603
EOF

# Update to new version (explicit digest change)
NEW_DIGEST=$(crane digest nginx:1.22.0)
kubectl patch deployment web --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/image",
    "value": "nginx@'${NEW_DIGEST}'"
  },
  {
    "op": "replace",
    "path": "/metadata/annotations/image-tag",
    "value": "nginx:1.22.0"
  }
]'
```

---

## Troubleshooting

### Image Pull Errors with Digests

**Error**: `Failed to pull image "nginx@sha256:...": rpc error: code = NotFound`

```bash
# Verify digest exists in registry
crane manifest nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603

# Check if digest is for correct architecture
crane manifest nginx@sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603 | jq '.config.platform'

# Get multi-arch digest (manifest list)
crane digest nginx:1.21.6
```

### Digest Mismatch After Registry Migration

```bash
# Re-push image preserving digest
skopeo copy \
  docker://old-registry.com/app@sha256:abc123 \
  docker://new-registry.com/app@sha256:abc123

# Verify digest matches
crane digest old-registry.com/app@sha256:abc123
crane digest new-registry.com/app@sha256:abc123
```

---

## Related Resources

- **[OPA Image Security Templates →](security.md)** - Registry allowlists and tag validation
- **[OPA Image Verification Templates →](verification.md)** - Signature verification annotations
- **[OPA Base Image Templates →](base.md)** - Approved base image enforcement
- **[Kyverno Image Validation Templates →](../kyverno-image/validation.md)** - Kubernetes-native alternative with automatic conversion
- **[Decision Guide →](../decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page
