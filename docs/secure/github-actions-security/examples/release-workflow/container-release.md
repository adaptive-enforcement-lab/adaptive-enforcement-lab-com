---
title: Container Release Workflows
description: >-
  Signed container releases with SLSA provenance and multi-architecture builds
---

        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=sha,prefix={{branch}}-

      # SECURITY: Build and push with provenance and SBOM
      - name: Build and push container
        id: push
        uses: docker/build-push-action@4a13e500e55cf31b7a5d59a38ab2040ab0f42f56  # v5.1.0
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          # SECURITY: Enable provenance and SBOM attestations
          provenance: true    # SLSA provenance
          sbom: true          # Software Bill of Materials
          # SECURITY: Build args for reproducibility
          build-args: |
            VERSION=${{ github.ref_name }}
            COMMIT=${{ github.sha }}
            BUILD_DATE=${{ github.event.head_commit.timestamp }}

      # SECURITY: Attest container provenance with GitHub attestations
      - name: Attest container image
        uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true

# Job 2: Scan container for vulnerabilities before release

  scan:
    needs: build-container
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write  # Upload SARIF
    steps:
      # SECURITY: Scan with Trivy for vulnerabilities
      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          image-ref: ghcr.io/${{ github.repository }}:${{ github.ref_name }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          # SECURITY: Fail on critical vulnerabilities
          exit-code: '1'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'trivy-results.sarif'
          category: 'container-scan'

# Job 3: Sign container with Cosign

  sign:
    needs: [build-container, scan]
    runs-on: ubuntu-latest
    environment: production
    permissions:
      packages: write  # Push signatures
      id-token: write  # Keyless signing with OIDC
    steps:
      # SECURITY: Install Cosign for keyless signing
      - name: Install Cosign
        uses: sigstore/cosign-installer@59acb6260d9c0ba8f4a2f9d9b48431a222b68e20  # v3.5.0

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@343f7c4344506bcbf9b4de18042ae17996df046d  # v3.0.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # SECURITY: Sign container with keyless Cosign (OIDC-based)
      # Signature stored in transparency log (Rekor)
      - name: Sign container image
        run: |
          cosign sign --yes \
            ghcr.io/${{ github.repository }}@${{ needs.build-container.outputs.digest }}
        env:
          COSIGN_EXPERIMENTAL: 1  # Enable keyless signing

      # SECURITY: Attest SBOM with Cosign
      - name: Attest SBOM
        run: |
          cosign attest --yes \
            --predicate <(cosign download sbom ghcr.io/${{ github.repository }}@${{ needs.build-container.outputs.digest }}) \
            ghcr.io/${{ github.repository }}@${{ needs.build-container.outputs.digest }}
        env:
          COSIGN_EXPERIMENTAL: 1

```

**Registry**: GitHub Container Registry (GHCR) with OIDC authentication. No long-lived credentials.

### Multi-Architecture Container Release

Build and release containers for multiple architectures with unified manifests.

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

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@f95db51fddba0c2d1ec667646a06c2ce06100226  # v3.0.0

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

      # SECURITY: Build for specific platform with provenance
      - name: Build and push by digest
        id: build
        uses: docker/build-push-action@4a13e500e55cf31b7a5d59a38ab2040ab0f42f56  # v5.1.0
        with:
          context: .
          platforms: ${{ matrix.platform }}
          push: true
          labels: ${{ steps.meta.outputs.labels }}
          provenance: mode=max  # Maximum provenance detail
          sbom: true
          # SECURITY: Output digest for manifest creation
          outputs: type=image,name=ghcr.io/${{ github.repository }},push-by-digest=true,name-canonical=true

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

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@f95db51fddba0c2d1ec667646a06c2ce06100226  # v3.0.0

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
          docker buildx imagetools create \
            $(jq -cr '.tags | map("-t " + .) | join(" ")' <<< "$DOCKER_METADATA_OUTPUT_JSON") \
            $(printf 'ghcr.io/${{ github.repository }}@sha256:%s ' *)

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

## NPM Package Release

Secure workflow for publishing npm packages with provenance statements.

### NPM with Provenance

Publish to npm registry with automated provenance generation.

```yaml
name: NPM Release with Provenance
on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read

jobs:
  # Job 1: Publish to npm with provenance
  publish-npm:
    runs-on: ubuntu-latest
    environment:
      name: npm-production
      url: https://www.npmjs.com/package/${{ github.event.repository.name }}
    permissions:
      contents: read
      id-token: write  # Generate provenance
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
          registry-url: 'https://registry.npmjs.org'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Build package
        run: npm run build

      # SECURITY: Verify package contents before publishing
      - name: Verify package contents
        run: |
          npm pack --dry-run
          echo "Package contents:"
          tar -tzf "$(npm pack)"

      # SECURITY: Publish with provenance
      # Provenance links package to source repository and build
      - name: Publish to npm
        run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}

  # Job 2: Publish to GitHub Packages
  publish-github:
    runs-on: ubuntu-latest
    environment: github-packages
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
