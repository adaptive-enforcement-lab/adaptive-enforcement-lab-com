---
description: >-
  Kyverno base image enforcement. Restrict allowed base images to approved, secure, and maintained distributions.
tags:
  - kyverno
  - image-security
  - base-images
  - kubernetes
  - templates
---

# Kyverno Base Image Enforcement

Enforces base image standards. Restricts container images to approved base images only, preventing teams from using arbitrary or vulnerable base images.

!!! tip "Centralize Base Image Management"
    Maintain a curated library of approved base images in your registry. Update them centrally, enforce propagation through policies, and block deprecated or EOL distributions.

---

## Template 4: Base Image Enforcement

Restricts container images to approved base images only. Prevents teams from using arbitrary base images that may contain vulnerabilities or lack security patches.

### Complete Policy

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-base-images
  namespace: kyverno
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: approved-base-images
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
        message: >-
          Container images must use approved base images from the allowlist:
          registry.example.com/base/alpine, registry.example.com/base/ubuntu,
          registry.example.com/base/distroless, registry.example.com/base/wolfi
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - image: "registry.example.com/base/alpine* | registry.example.com/base/ubuntu* | registry.example.com/base/distroless* | registry.example.com/base/wolfi*"
    - name: block-deprecated-base-images
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
        message: "Deprecated base images are not allowed: centos, ubuntu:18.04, alpine:3.12"
        deny:
          conditions:
            any:
              - key: "{{ images.containers.*.name }}"
                operator: AnyIn
                value: ["*centos*", "*ubuntu:18.04*", "*alpine:3.12*", "*debian:9*"]
    - name: require-minimal-base-images
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
          selector:
            matchLabels:
              security.enforce: "high"
      validate:
        message: "High-security workloads must use minimal base images: distroless or wolfi only"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - image: "registry.example.com/base/distroless* | registry.example.com/base/wolfi*"
    - name: validate-base-image-version
      match:
        resources:
          kinds:
            - Pod
            - Deployment
            - StatefulSet
            - DaemonSet
            - Job
            - CronJob
      preconditions:
        any:
          - key: "{{ request.object.spec.template.spec.containers[].image }}"
            operator: Contains
            value: "ubuntu"
      validate:
        message: "Ubuntu base images must be version 22.04 or 24.04"
        pattern:
          spec:
            (template)?:
              spec:
                containers:
                  - image: "*ubuntu:22.04* | *ubuntu:24.04*"
```

### Customization Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `validationFailureAction` | `enforce` | Use `audit` for initial rollout |
| `approved-base-images` | alpine, ubuntu, distroless, wolfi | Allowlist of base images |
| `deprecated-base-images` | centos, ubuntu:18.04 | Blocklist of EOL images |
| `minimal-base-images` | distroless, wolfi | Minimal attack surface images |
| `high-security-label` | `security.enforce: high` | Namespaces requiring minimal images |

### Validation Commands

```bash
# Apply policy
kubectl apply -f base-image-policy.yaml

# Test with unapproved base image (should fail)
kubectl run test --image=debian:12 -n default

# Test with approved base image (should pass)
kubectl run test --image=registry.example.com/base/alpine:3.19 -n default

# Test deprecated image (should fail)
kubectl run test --image=centos:7 -n default

# Audit existing images in cluster
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | grep -v "registry.example.com/base"

# Check base image policy violations
kubectl get clusterpolicies enforce-base-images -o yaml
kubectl describe clusterpolicy enforce-base-images
```

### Use Cases

1. **Standardization**: Enforce consistent base images across all teams
2. **Patch Management**: Centrally update base images, force propagation to teams
3. **Vulnerability Reduction**: Block images with known CVEs in base layers
4. **License Compliance**: Ensure only approved OS distributions with compatible licenses
5. **Supply Chain Security**: Verify base images come from trusted internal registry

### Creating a Base Image Library

Build and maintain approved base images:

```dockerfile
# Example approved base image: registry.example.com/base/alpine
FROM alpine:3.19
LABEL org.opencontainers.image.source="https://github.com/example/base-images"
LABEL org.opencontainers.image.created="2024-01-15T10:00:00Z"
LABEL security.scan.passed="true"
LABEL security.scan.date="2024-01-15"

# Install security updates
RUN apk upgrade --no-cache && \
    apk add --no-cache ca-certificates tzdata && \
    rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1000 app && \
    adduser -u 1000 -G app -s /bin/sh -D app

# Security hardening
RUN chmod 700 /root && \
    chmod 755 /home/app

USER 1000:1000
```

Automated base image updates:

```yaml
# .github/workflows/update-base-images.yml
name: Update Base Images
on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Update alpine base
        run: |
          docker pull alpine:3.19
          docker build -t registry.example.com/base/alpine:3.19 -f base/alpine.Dockerfile .
          docker push registry.example.com/base/alpine:3.19

      - name: Scan for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: registry.example.com/base/alpine:3.19
          severity: 'CRITICAL,HIGH'
          exit-code: 1

      - name: Sign image
        run: |
          cosign sign --yes registry.example.com/base/alpine:3.19
```

---

## Related Resources

- **[Kyverno CVE Scanning Gates →](cve-scanning.md)** - Vulnerability scan attestations
- **[Kyverno Image Signing →](signing.md)** - Cosign signature verification
- **[Kyverno Image Validation →](validation.md)** - Digest requirements and registry allowlists
- **[Kyverno Pod Security →](../kyverno-pod-security/standards.md)** - Security contexts and capabilities
- **[Template Library Overview →](../index.md)** - Back to main page
