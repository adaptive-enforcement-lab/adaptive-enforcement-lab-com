---
title: Advanced SLSA Patterns for Go
tags:
  - slsa
  - provenance
  - go
  - golang
  - containers
  - docker
  - supply-chain
  - security
  - attestation
  - developers
  - operators
description: >-
  Advanced SLSA patterns for Go: container images with distroless, provenance verification with slsa-verifier, common gotchas, and production best practices.
---
# Advanced SLSA Patterns for Go

Container images, verification workflows, and production best practices.

!!! info "Prerequisites"
    Read [Go Integration](go-integration.md) first for core binary build patterns. This guide covers advanced scenarios.

---

## Pattern 4: Container Images with Go Binaries

Build Go binary, package in distroless container, generate provenance.

```yaml
jobs:
  build:
    permissions:
      contents: read
      packages: write
    runs-on: ubuntu-latest
    outputs:
      image-digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v5
        id: build
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          platforms: linux/amd64,linux/arm64
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Generate provenance subject
        id: hash
        run: |
          echo "hashes=$(echo 'ghcr.io/${{ github.repository }}@${{ steps.build.outputs.digest }}' | base64 -w0)" >> "$GITHUB_OUTPUT"

  provenance:
    needs: [build]
    permissions:
      actions: read
      id-token: write
      packages: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2.1.0
    with:
      image: ghcr.io/${{ github.repository }}
      digest: ${{ needs.build.outputs.digest }}
```

### Dockerfile Pattern

```dockerfile
# Build stage
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /app ./cmd/myapp

# Runtime stage
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app /app
ENTRYPOINT ["/app"]
```

**Distroless advantage**: Minimal attack surface, no shell, no package manager. Perfect for Go static binaries.

---

## Verification

Verify Go binary provenance with `slsa-verifier`:

```bash
# Download binary and provenance
gh release download v1.0.0 --pattern 'myapp_linux_amd64'
gh release download v1.0.0 --pattern '*.intoto.jsonl'

# Verify provenance
slsa-verifier verify-artifact myapp_linux_amd64 \
  --provenance-path *.intoto.jsonl \
  --source-uri github.com/org/repo
```

**Expected output**:

```text
Verified signature against tlog entry index 12345678 at URL: https://rekor.sigstore.dev/api/v1/log/entries/...
Verified build using builder "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@refs/tags/v2.1.0" at commit abc123...
PASSED: Verified SLSA provenance
```

---

## Container Image Verification

```bash
# Verify container image provenance
slsa-verifier verify-image \
  ghcr.io/org/repo:v1.0.0 \
  --provenance-path image.intoto.jsonl \
  --source-uri github.com/org/repo
```

**Integration with deployment**:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: slsa-framework/slsa-verifier/actions/installer@v2.6.0
      - run: |
          slsa-verifier verify-image \
            ghcr.io/${{ github.repository }}:${{ inputs.tag }} \
            --source-uri "github.com/${{ github.repository }}"
      - run: kubectl set image deployment/app app=ghcr.io/${{ github.repository }}:${{ inputs.tag }}
```

---

## Common Go-Specific Gotchas

| Issue | Symptom | Fix |
|-------|---------|-----|
| Build path leakage | Provenance includes local file paths | Use `-trimpath` flag |
| Non-deterministic timestamps | Build time embedded in binary | Use `-ldflags="-X main.buildTime=$(date -u)"` |
| CGO builds fail verification | Different libc versions across systems | Use `CGO_ENABLED=0` for static binaries |
| Module checksum mismatch | `go.sum` changes between builds | Commit `go.sum`, run `go mod verify` in CI |
| Large binary sizes | Debug symbols inflate provenance hash | Use `-ldflags="-s -w"` to strip symbols |

---

## Best Practices

**Use `-trimpath`**: Always. Removes build-time file paths for reproducibility.

**Static binaries with `CGO_ENABLED=0`**: Simplifies deployment, improves reproducibility.

**Version injection with `-ldflags`**: Embed git commit, version tag, build time for traceability.

**Multi-platform in single job**: Generate consistent provenance for all platforms.

**Verify `go.sum`**: Run `go mod verify` in build workflow before compilation.

**Pin Go version**: Use `go-version-file: go.mod` for consistency.

**Distroless for containers**: Minimal attack surface, no shell, perfect for static Go binaries.

**Verify before deploy**: Block deployments if provenance verification fails. Fail closed, never open.

---

## Integration Checklist

Before deploying Go binaries with SLSA provenance:

- [ ] Build uses `-trimpath` flag
- [ ] Debug symbols stripped with `-ldflags="-s -w"`
- [ ] `CGO_ENABLED=0` for static binaries (unless CGO required)
- [ ] Version info injected with `-ldflags -X`
- [ ] `go.sum` committed and verified in CI
- [ ] Multi-platform builds use consistent flags
- [ ] Provenance uploaded to GitHub Releases
- [ ] Verification automated in deployment workflow
- [ ] Renovate configured to skip SHA pins for slsa-github-generator
- [ ] Container images use distroless or minimal base
- [ ] Deployment gates verify provenance before kubectl apply

---

## Troubleshooting

### Verification Fails with "source URI mismatch"

**Cause**: Built from fork or different repository

**Fix**: Verify `--source-uri` matches actual build repository. Check for fork confusion.

### Provenance Hash Doesn't Match Artifact

**Cause**: Artifact modified after build, or build not reproducible

**Fix**: Re-build. Check for non-deterministic build inputs (timestamps, absolute paths).

### slsa-verifier Not Found

**Cause**: Tool not installed in deployment environment

**Fix**: Use `slsa-framework/slsa-verifier/actions/installer@v2.6.0` in GitHub Actions.

### Container Image Verification Fails

**Cause**: Using wrong verification command for images

**Fix**: Use `verify-image`, not `verify-artifact`, for container images.

---

## FAQ

**Can I use SLSA with private Go modules?** Yes. SLSA verifies build integrity, not module visibility. Private modules work normally.

**What about CGO builds?** CGO builds work but lose reproducibility across different libc versions. Consider static builds or document libc requirements.

**Does SLSA work with Go workspaces?** Yes. Build from workspace root, provenance covers all modules.

**How do I verify container images?** Use `slsa-verifier verify-image` instead of `verify-artifact`. See Pattern 4 above.

**Can I use GoReleaser Pro features?** Yes. SLSA provenance works with both OSS and Pro versions.

**What if my build needs CGO?** Document libc requirements. Use specific base images. Verify on target platform. Consider separate static and CGO builds.

**How do I handle multi-arch container images?** Use `docker/build-push-action` with `platforms: linux/amd64,linux/arm64`. Provenance covers manifest list.

---

## Related Content

- **[Go Integration](go-integration.md)**: Core binary build patterns
- **[SLSA Implementation Playbook](../index.md)**: Complete adoption guide
- **[Verification Workflows](../verification-workflows.md)**: Automate provenance verification
- **[Policy Templates](../policy-templates.md)**: Kyverno and OPA policies for enforcement
- **[Runner Configuration](../runner-configuration.md)**: Self-hosted vs GitHub-hosted considerations

---

*Verification turns provenance from evidence to enforcement.*
