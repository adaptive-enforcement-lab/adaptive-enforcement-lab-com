---
description: >-
  OPA Gatekeeper base image enforcement. Require approved base images and block deprecated or vulnerable base image patterns.
tags:
  - opa
  - gatekeeper
  - base-images
  - image-security
  - kubernetes
  - templates
---

# OPA Base Image Templates

Enforces approved base images for container builds. Blocks deprecated base images and requires standardized base image patterns for supply chain security.

!!! danger "Base Image Defines Trust Foundation"
    Base images contain the OS, libraries, and dependencies your application runs on. Unapproved base images can introduce vulnerabilities, malware, or compliance violations that affect all derived images.

---

## Template 5: Base Image Enforcement

Requires containers use approved base images. Blocks deprecated base images and enforces organizational standards.

### Complete Policy

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: k8sapprovedbaseimages
spec:
  crd:
    spec:
      names:
        kind: K8sApprovedBaseImages
      validation:
        openAPIV3Schema:
          properties:
            approvedBaseImages:
              type: array
              items:
                type: string
              description: "Approved base image prefixes"
            deprecatedBaseImages:
              type: array
              items:
                type: string
              description: "Deprecated base images that must not be used"
            requireBaseImageAnnotation:
              type: boolean
              description: "Require annotation declaring base image"
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8sapprovedbaseimages

        violation[{"msg": msg, "details": {}}] {
          input.parameters.requireBaseImageAnnotation
          not input.review.object.metadata.annotations["base-image"]
          msg := "Annotation 'base-image' is required to declare which base image was used in build"
        }

        violation[{"msg": msg, "details": {}}] {
          input.parameters.requireBaseImageAnnotation
          base_image := input.review.object.metadata.annotations["base-image"]
          not approved_base_image(base_image)
          msg := sprintf("Base image '%v' is not in approved list: %v",
            [base_image, input.parameters.approvedBaseImages])
        }

        violation[{"msg": msg, "details": {}}] {
          base_image := input.review.object.metadata.annotations["base-image"]
          deprecated_base_image(base_image)
          msg := sprintf("Base image '%v' is deprecated and must not be used. Migrate to approved alternatives: %v",
            [base_image, input.parameters.approvedBaseImages])
        }

        violation[{"msg": msg, "details": {}}] {
          container := input_containers[_]
          # Detect common deprecated base image patterns in image name
          deprecated_pattern(container.image)
          msg := sprintf("Container %v appears to use deprecated base image pattern: %v. Use approved base images: %v",
            [container.name, container.image, input.parameters.approvedBaseImages])
        }

        approved_base_image(image) {
          approved := input.parameters.approvedBaseImages[_]
          startswith(image, approved)
        }

        deprecated_base_image(image) {
          deprecated := input.parameters.deprecatedBaseImages[_]
          startswith(image, deprecated)
        }

        deprecated_pattern(image) {
          deprecated := input.parameters.deprecatedBaseImages[_]
          contains(image, deprecated)
        }

        input_containers[c] {
          c := input.review.object.spec.containers[_]
        }

        input_containers[c] {
          c := input.review.object.spec.initContainers[_]
        }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sApprovedBaseImages
metadata:
  name: approved-base-images
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
    requireBaseImageAnnotation: true
    approvedBaseImages:
      - "gcr.io/distroless/static-debian12"
      - "gcr.io/distroless/base-debian12"
      - "docker.io/library/alpine:3.19"
      - "docker.io/library/alpine:3.18"
      - "docker.io/library/ubuntu:22.04"
      - "docker.io/library/ubuntu:24.04"
      - "registry.access.redhat.com/ubi9/ubi-minimal"
      - "cgr.dev/chainguard/static"
    deprecatedBaseImages:
      - "debian:9"
      - "debian:10"
      - "ubuntu:16.04"
      - "ubuntu:18.04"
      - "ubuntu:20.04"
      - "alpine:3.14"
      - "alpine:3.15"
      - "busybox"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `approvedBaseImages` | Curated list | Approved base image prefixes |
| `deprecatedBaseImages` | EOL versions | Deprecated base images to block |
| `requireBaseImageAnnotation` | `true` | Require annotation declaring base image |
| `enforcementAction` | `deny` | Use `dryrun` for gradual rollout |

### Validation Commands

```bash
# Apply policy
kubectl apply -f opa-base-image-enforcement.yaml

# Verify installation
kubectl get constrainttemplates k8sapprovedbaseimages
kubectl get k8sapprovedbaseimages

# Test without base-image annotation (should fail)
kubectl run test --image=registry.example.com/app:v1.0.0

# Test with deprecated base image (should fail)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: deprecated-base
  annotations:
    base-image: "ubuntu:18.04"
spec:
  containers:
    - name: app
      image: registry.example.com/app:v1.0.0
EOF

# Test with approved base image (should pass)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: approved-base
  annotations:
    base-image: "gcr.io/distroless/static-debian12"
spec:
  containers:
    - name: app
      image: registry.example.com/app@sha256:abc123...
EOF

# Check violations
kubectl get k8sapprovedbaseimages approved-base-images -o yaml

# Audit base images in use
kubectl get pods -A -o json | jq -r '
  .items[] |
  "\(.metadata.namespace)/\(.metadata.name): \(.metadata.annotations["base-image"] // "NOT_DECLARED")"
'
```

### Use Cases

1. **Vulnerability Reduction**: Block base images with known CVEs or no security updates
2. **Compliance Requirements**: Enforce FedRAMP or FIPS approved base images
3. **Supply Chain Security**: Ensure base images come from trusted vendors
4. **Cost Optimization**: Standardize on minimal base images to reduce storage and transfer costs
5. **Migration Enforcement**: Force migration from deprecated to supported base images

---

## CI/CD Integration

Extract base image from Dockerfile and add annotation to deployment.

### GitHub Actions Example

```yaml
name: Build and Annotate
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Extract base image from Dockerfile
        id: base-image
        run: |
          BASE_IMAGE=$(grep "^FROM.*AS runtime" Dockerfile | awk '{print $2}')
          echo "base_image=${BASE_IMAGE}" >> $GITHUB_OUTPUT

      - name: Build and push image
        run: |
          docker build -t registry.example.com/app:${{ github.sha }} .
          docker push registry.example.com/app:${{ github.sha }}

      - name: Deploy with base image annotation
        run: |
          kubectl apply -f - <<EOF
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: web
            annotations:
              base-image: "${{ steps.base-image.outputs.base_image }}"
          spec:
            template:
              spec:
                containers:
                  - name: app
                    image: registry.example.com/app:${{ github.sha }}
          EOF
```

### Dockerfile Best Practices

```dockerfile
# Use approved base image
FROM gcr.io/distroless/static-debian12:latest AS runtime

# Multi-stage build
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o /app/server

FROM runtime
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
```

---

## Base Image Governance

### Recommended Base Images by Use Case

| Use Case | Recommended Base Image | Rationale |
|----------|------------------------|-----------|
| Static binaries | `gcr.io/distroless/static-debian12` | No shell, minimal attack surface |
| Dynamic binaries | `gcr.io/distroless/cc-debian12` | glibc included, still minimal |
| Python apps | `cgr.dev/chainguard/python:latest` | Minimal, regularly patched |
| Node.js apps | `cgr.dev/chainguard/node:latest` | Minimal, Node LTS versions |
| Java apps | `gcr.io/distroless/java17-debian12` | JRE included, minimal OS |
| FedRAMP/FIPS | `registry.access.redhat.com/ubi9/ubi-minimal` | FIPS certified |

### Selection Criteria

1. **Security**: Regular security updates, CVE scanning, minimal attack surface
2. **Maintenance**: Active maintenance, predictable release schedule
3. **Provenance**: Signed images, SLSA provenance, transparent build process
4. **Size**: Minimal size to reduce attack surface and registry costs
5. **Compatibility**: Supports required runtime

---

## Troubleshooting

### Base Image Annotation Missing

```bash
# Extract base image from Dockerfile
BASE_IMAGE=$(grep "^FROM" Dockerfile | tail -1 | awk '{print $2}')

# Add annotation to deployment
kubectl annotate deployment web base-image="${BASE_IMAGE}"
```

### Multi-stage Build Detection

For multi-stage builds, annotate with the final runtime base:

```dockerfile
FROM golang:1.21 AS builder
# Build steps...

FROM gcr.io/distroless/static-debian12 AS runtime
COPY --from=builder /app/server /server
# Annotate with runtime base, not builder base
```

### Deprecated Base Image Migration

```bash
# Find all workloads using deprecated base images
kubectl get deployments -A -o json | jq -r '
  .items[] |
  select(.metadata.annotations["base-image"] | startswith("ubuntu:18.04")) |
  "\(.metadata.namespace)/\(.metadata.name)"
'

# Batch update annotation
kubectl get deployments -A -o json | jq -r '
  .items[] |
  select(.metadata.annotations["base-image"] == "ubuntu:18.04") |
  "\(.metadata.namespace) \(.metadata.name)"
' | while read ns name; do
  kubectl annotate deployment -n ${ns} ${name} base-image="ubuntu:22.04" --overwrite
done
```

---

## Related Resources

- **[OPA Image Security Templates →](opa-image-security.md)** - Registry allowlists and tag validation
- **[OPA Image Digest Templates →](opa-image-digest.md)** - SHA256 digest enforcement
- **[OPA Image Verification Templates →](opa-image-verification.md)** - Signature verification annotations
- **[Kyverno Image Security Templates →](kyverno-image-security.md)** - Kubernetes native base image enforcement
- **[Decision Guide →](decision-guide.md)** - OPA vs Kyverno selection
- **[Template Library Overview →](index.md)** - Back to main page

---

## External Documentation

- **[Distroless Images](https://github.com/GoogleContainerTools/distroless)** - Minimal base images from Google
- **[Chainguard Images](https://www.chainguard.dev/chainguard-images)** - Minimal, signed base images
- **[Red Hat UBI](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)** - Enterprise base images
- **[Alpine Linux](https://www.alpinelinux.org/)** - Minimal Linux distribution
