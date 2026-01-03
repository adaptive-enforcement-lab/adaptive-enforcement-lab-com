---
title: Multi-Architecture Container Builds
description: >-
  Build and release multi-architecture container images with unified manifests, platform-specific attestations, and buildah-based OCI tooling for amd64 and arm64
---

!!! tip "Unified Manifest Lists"

    Multi-architecture builds create separate images for each platform, then combine them into a single manifest list. Users pulling the image automatically get the correct architecture without specifying platform tags.

Build and release containers for multiple architectures with unified manifests.

## Multi-Architecture Container Release

Complete workflow for building amd64 and arm64 images with manifest list aggregation.

```yaml
name: Multi-Arch Container Release
on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read

jobs:
  # Job 1: Build matrix for multiple architectures
  build-matrix:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
    strategy:
      matrix:
        platform:
          - linux/amd64
          - linux/arm64
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Set up QEMU for cross-platform builds
      - name: Set up QEMU
        uses: docker/setup-qemu-action@68827325e0b33c7199eb31dd4e31fbe9023e06e3  # v3.0.0

      # SECURITY: Set up OCI build tooling
      - name: Set up buildah
        run: |
          sudo apt-get update
          sudo apt-get install -y buildah

      - name: Log in to GHCR
        uses: docker/login-action@343f7c4344506bcbf9b4de18042ae17996df046d  # v3.0.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@8e5442c4ef9f78752691e2d8f8d19755c6f78e81  # v5.5.1
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=sha

      # SECURITY: Build for specific platform with buildah
      - name: Build and push by digest
        id: build
        run: |
          PLATFORM="${{ matrix.platform }}"
          IMAGE_NAME="ghcr.io/${{ github.repository }}"

          # Build multi-arch image
          buildah build \
            --platform "${PLATFORM}" \
            --label org.opencontainers.image.version="${{ github.ref_name }}" \
            --tag "${IMAGE_NAME}:${PLATFORM//\//-}" \
            .

          # Push to registry
          buildah push "${IMAGE_NAME}:${PLATFORM//\//-}"

          # Get digest
          DIGEST=$(buildah inspect "${IMAGE_NAME}:${PLATFORM//\//-}" | jq -r '.Digest')
          echo "digest=${DIGEST}" >> $GITHUB_OUTPUT

      # SECURITY: Attest each platform image
      - name: Attest platform image
        uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.build.outputs.digest }}
          push-to-registry: true

      # SECURITY: Export digest for manifest list
      - name: Export digest
        run: |
          mkdir -p /tmp/digests
          digest="${{ steps.build.outputs.digest }}"
          platform="${{ matrix.platform }}"
          touch "/tmp/digests/${digest#sha256:}"
          echo "$platform" > "/tmp/digests/${digest#sha256:}.platform"

      - name: Upload digest
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: digests-${{ strategy.job-index }}
          path: /tmp/digests/*
          retention-days: 1

  # Job 2: Create multi-arch manifest
  manifest:
    needs: build-matrix
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: write
      packages: write
      id-token: write
    steps:
      - name: Download digests
        uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16  # v4.1.8
        with:
          path: /tmp/digests
          pattern: digests-*
          merge-multiple: true

      # SECURITY: Set up OCI build tooling
      - name: Set up buildah
        run: |
          sudo apt-get update
          sudo apt-get install -y buildah

      - name: Log in to GHCR
        uses: docker/login-action@343f7c4344506bcbf9b4de18042ae17996df046d  # v3.0.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@8e5442c4ef9f78752691e2d8f8d19755c6f78e81  # v5.5.1
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=sha

      # SECURITY: Create manifest list from platform digests
      - name: Create manifest list and push
        working-directory: /tmp/digests
        run: |
          IMAGE_NAME="ghcr.io/${{ github.repository }}"
          VERSION="${{ github.ref_name }}"

          # Create manifest list
          buildah manifest create "${IMAGE_NAME}:${VERSION}"

          # Add all platform digests to manifest
          for digest in sha256:*; do
            buildah manifest add "${IMAGE_NAME}:${VERSION}" "${IMAGE_NAME}@${digest}"
          done

          # Push manifest list
          buildah manifest push --all "${IMAGE_NAME}:${VERSION}" "docker://${IMAGE_NAME}:${VERSION}"

      # SECURITY: Create GitHub release with manifest reference
      - name: Create GitHub release
        uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          generate_release_notes: true
          body: |
            ## Container Images

            Multi-architecture container images available at:
            ```
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ```

            Supported platforms:
            - linux/amd64
            - linux/arm64

            ### Verification

            Verify image signatures with Cosign:
            ```bash
            cosign verify \
              --certificate-identity-regexp="^https://github.com/${{ github.repository }}" \
              --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
              ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ```
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Architecture Support**: amd64, arm64 with unified manifest list.

## Key Patterns

**Matrix Build Strategy**:

- Build job runs once per platform using `strategy.matrix.platform`
- Each platform build creates separate image with platform tag
- Digests exported as artifacts for manifest aggregation

**Manifest List Creation**:

- Download all platform digests from artifacts
- Create manifest list referencing all platform images by digest
- Push manifest list to registry with semantic version tags

**Security Controls**:

- Platform-specific attestations for each architecture
- OIDC authentication to GHCR (no stored credentials)
- Provenance linked to each platform build
- Environment protection for production releases

## Platform Support

**Common Platforms**:

```yaml
strategy:
  matrix:
    platform:
      - linux/amd64    # x86_64
      - linux/arm64    # ARM 64-bit
      - linux/arm/v7   # ARM 32-bit
      - linux/ppc64le  # PowerPC 64-bit
      - linux/s390x    # IBM Z mainframe
```

**QEMU Emulation**:

Use `docker/setup-qemu-action` to enable cross-platform builds on GitHub-hosted runners. QEMU emulates non-native architectures, allowing amd64 runners to build arm64 images.

## Related Patterns

- **[Single-Architecture Containers](container-release.md)**: Simplified workflow for single-platform images
- **[Package Release Checklist](package-release-checklist.md)**: Security checklist for all release types
- **[Action Pinning](../../action-pinning/sha-pinning.md)**: SHA-256 pinning for supply chain security
- **[Environment Protection](../../workflows/environments/index.md)**: Deployment gates and approval workflows

## Summary

Multi-architecture container releases require:

1. **Matrix strategy** to build each platform in parallel
2. **Digest export** via artifacts for manifest aggregation
3. **Manifest list creation** combining all platform images
4. **Platform-specific attestations** for supply chain security
5. **QEMU emulation** for cross-platform builds on GitHub runners

Use this pattern for containers deployed across heterogeneous infrastructure or distributed to users on multiple architectures.
