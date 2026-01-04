---
title: Maintenance and Best Practices
description: >-
  Troubleshoot container builds, optimize image size, and maintain tool versions. Best practices for pinning dependencies and testing policy-platform images.
---
# Maintenance and Best Practices

Troubleshooting container builds, best practices, and included tools reference.

## Troubleshooting

### Build Failures

**Problem**: `no such image` when pulling policy repo

**Cause**: Policy repo not pushed or authentication failed

**Solution**: Verify policy repo exists and credentials are correct

```bash
# Test pulling policy repo
docker pull europe-west6-docker.pkg.dev/project/charts/security-policy-repo:main

# Check authentication
docker login europe-west6-docker.pkg.dev
```

### Tool Installation Failures

**Problem**: `curl: command not found`

**Cause**: Tool not installed in base image

**Solution**: Install dependencies first

```dockerfile
RUN apk add curl bash ca-certificates
```

### Large Image Size

**Problem**: Image exceeds 1GB

**Cause**: Build cache or unnecessary files included

**Solution**: Use multi-stage builds and `.dockerignore`

```dockerfile
# .dockerignore
.git
*.md
tests/
```

!!! tip "Debug with --no-cache"
    Build failures? Use `docker build --no-cache` to eliminate cached layer issues.

---

## Best Practices

### 1. Pin All Versions

**Tools**:

```dockerfile
FROM alpine:3.22.1  # Not :latest
RUN curl ...v1.13.2/kyverno...  # Not /latest/
```

**Policy repos**:

```dockerfile
FROM security-policy-repo:v2.1.2  # Not :main
```

### 2. Layer Order Optimization

Put frequently changing layers last:

```dockerfile
# Rarely changes - put first
RUN apk add curl bash

# Changes occasionally - put middle
COPY --from=security_policy_repo /repos/ /repos/

# Changes frequently - put last
COPY ./scripts/ /scripts/
```

### 3. Security Scanning

Scan every build:

```yaml
- trivy image --severity HIGH,CRITICAL policy-platform:latest
```

### 4. Test Before Push

Never push untested images:

```bash
docker build -t policy-platform:test .
docker run policy-platform:test kyverno version
docker push policy-platform:test  # Only after tests pass
```

### 5. Document Tool Versions

Maintain `VERSIONS.md`:

```markdown
# Tool Versions

- Kyverno CLI: v1.13.2
- Pluto: v5.21.1
- Spectral: latest
- Helm: Alpine package (3.14.x)
- yq: Alpine package (4.x)
```

---

## Included Tools

### Kyverno CLI

**Version**: v1.13.2

**Usage**:

```bash
kyverno apply policy.yaml --resource manifest.yaml
```

### Pluto

**Version**: v5.21.1

**Usage**:

```bash
pluto detect manifest.yaml --target-versions k8s=v1.29.0
```

### Spectral

**Version**: Latest (dynamically fetched)

**Usage**:

```bash
spectral lint -r .spectral.yaml values.yaml
```

### Helm

**Version**: Alpine package (3.14.x)

**Usage**:

```bash
helm template app /charts/app -f values.yaml
```

### yq

**Version**: Alpine package (4.x)

**Usage**:

```bash
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' base.yaml override.yaml
```

---

## Policy Sources

This container aggregates policies from:

- **security-policy**: Security and compliance policies
- **devops-policy**: Operational best practices
- **backend-applications**: Application schemas and templates

For details, see **[Multi-Source Policies](../multi-source-policies/index.md)**.

---

## Next Steps

- **[Local Development](../local-development/index.md)** - Use policy-platform locally
- **[CI Integration](../ci-integration/index.md)** - Automated pipeline validation
- **[Operations](../operations/index.md)** - Day-to-day management
