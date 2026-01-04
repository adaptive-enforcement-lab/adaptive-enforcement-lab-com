---
title: Distribution and Testing
description: >-
  Version, test, and distribute policy-platform containers. Semantic versioning, security scanning with Trivy, and registry authentication patterns.
---
# Distribution and Testing

Versioning, testing, optimization, and distribution of the policy-platform container.

## Versioning Strategy

### Semantic Versioning

Policy-platform follows semantic versioning:

```bash
policy-platform:v2.1.3
```

**Version components**:

- **Major** (v2.x.x): Breaking changes (tool upgrades, policy structure changes)
- **Minor** (vx.1.x): New policy repos added, new tools
- **Patch** (vx.x.3): Policy updates, bug fixes

### Tagging Strategy

```bash
# Tag with version
docker tag policy-platform:latest policy-platform:v1.0.2

# Tag with commit SHA
docker tag policy-platform:latest policy-platform:sha-abc123

# Push all tags
docker push policy-platform:v1.0.2
docker push policy-platform:sha-abc123
docker push policy-platform:latest
```

!!! tip "Always Tag with Version AND SHA"
    Version tags for humans (`v1.0.2`). SHA tags for auditability (`sha-abc123`). Both enable rollbacks.

---

## Testing the Container

### Smoke Test

```bash
# Verify tools installed
docker run --rm policy-platform:latest kyverno version
docker run --rm policy-platform:latest pluto version
docker run --rm policy-platform:latest helm version

# Verify policies present
docker run --rm policy-platform:latest ls -R /repos/
```

### Integration Test

```bash
# Test complete validation workflow
docker run --rm -v $(pwd):/workspace policy-platform:latest bash -c '\
  helm template app /repos/backend-applications/charts/app \
    -f /repos/backend-applications/charts/app/values.yaml \
  | kyverno apply /repos/security-policy/ --resource -'
```

### CI Test Pipeline

```yaml
- step:
    name: Test Container
    script:
      - docker run policy-platform:${BUILD_NUMBER} kyverno version
      - docker run policy-platform:${BUILD_NUMBER} pluto version
      - docker run policy-platform:${BUILD_NUMBER} ls /repos/security-policy/
```

---

## Size Optimization

### Multi-Stage Build Benefits

```dockerfile
# Build tools in separate stages
FROM alpine:3.22.1 AS builder
RUN apk add build-base

# Final image only has binaries
FROM alpine:3.22.1
COPY --from=builder /usr/local/bin/kyverno /usr/local/bin/
```

### Layer Optimization

```dockerfile
# Combine RUN commands to reduce layers
RUN apk add curl bash && \
    curl -sSL ...kyverno.tar.gz | tar -xz && \
    curl -sSL ...pluto.tar.gz | tar -xz
```

### Image Size Comparison

```text
Before optimization: 850 MB
After optimization:  320 MB
```

---

## Distribution

### Registry Options

**Google Artifact Registry**:

```bash
docker push europe-west6-docker.pkg.dev/project/charts/policy-platform:v1.0.2
```

**GitHub Container Registry**:

```bash
docker push ghcr.io/org/policy-platform:v1.0.2
```

**Docker Hub** (public images):

```bash
docker push dockerhub-username/policy-platform:v1.0.2
```

!!! warning "Use Private Registries"
    Policy-platform contains proprietary policies. Use private registries (GCR, ACR, GHCR) with authentication.

### Registry Authentication

**CI authentication**:

```yaml
image:
  name: policy-platform:latest
  username: _json_key
  password: $GCLOUD_API_KEYFILE
```

---

## Updating the Container

### Update Workflow

1. Update policy repo dependencies
2. Increment version in `VERSION` file
3. Rebuild container
4. Run tests
5. Tag and push
6. Update deployments

**Example**:

```bash
# Update VERSION file
echo "v1.0.3" > VERSION

# Build
docker build -t policy-platform:$(cat VERSION) .

# Test
docker run policy-platform:$(cat VERSION) kyverno version

# Push
docker push policy-platform:$(cat VERSION)
```

### Automated Updates

```yaml
# Bitbucket schedule
pipelines:
  custom:
    weekly-rebuild:
      - step:
          name: Rebuild Policy Platform
          script:
            - docker build -t policy-platform:latest .
            - docker push policy-platform:latest
```

---

## Security Scanning

### Trivy Scan

```bash
# Scan for vulnerabilities
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image policy-platform:latest
```

### CI Integration

```yaml
- step:
    name: Security Scan
    script:
      - docker run aquasec/trivy image policy-platform:${BUILD_NUMBER}
```

**Fail build on critical vulnerabilities**:

```yaml
- trivy image --severity CRITICAL --exit-code 1 policy-platform:latest
```

---

## Next Steps

- **[Maintenance](maintenance.md)** - Troubleshooting and best practices
- **[Operations](../operations/index.md)** - Day-to-day policy management
- **[CI Integration](../ci-integration/index.md)** - Using policy-platform in CI
