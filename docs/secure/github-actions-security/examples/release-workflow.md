---
title: Hardened Release Workflow
description: >-
  Production-ready release workflow examples with signed releases, SLSA provenance, artifact attestations, and minimal permissions.
tags:
  - github-actions
  - security
  - releases
  - slsa
  - provenance
  - attestations
---

# Hardened Release Workflow

Copy-paste ready release workflow templates with comprehensive security hardening. Each example demonstrates signed releases, SLSA provenance generation, artifact attestations, minimal permissions, and secure artifact distribution.

!!! tip "Complete Security Patterns"

    These workflows integrate all security patterns from the hub: SHA-pinned actions, minimal GITHUB_TOKEN permissions, SLSA provenance, artifact attestations, signature verification, and secure distribution. Use as production templates for secure software supply chain.

## Release Security Principles

Every release workflow in this guide implements these controls:

1. **Action Pinning**: All third-party actions pinned to full SHA-256 commit hashes
2. **Minimal Permissions**: Only required permissions granted per job
3. **SLSA Provenance**: Build provenance attestations for supply chain transparency
4. **Artifact Attestations**: Cryptographic signatures for release artifacts
5. **Signature Verification**: Verifiable release authenticity
6. **Immutable Releases**: Tag protection and commit verification
7. **Approval Gates**: Environment protection for production releases

## GitHub Release Workflow

Secure workflow for creating GitHub releases with signed artifacts and SLSA provenance.

### Basic Signed Release

Minimal secure release workflow with artifact attestations.

```yaml
name: Secure Release
on:
  push:
    tags:
      # SECURITY: Only trigger on semantic version tags to prevent unauthorized releases
      - 'v*.*.*'

# SECURITY: Minimal permissions by default, escalated per job
permissions:
  contents: read

jobs:
  # Job 1: Build artifacts with attestations
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read      # Read repository code
      id-token: write     # Generate OIDC tokens for signing
      attestations: write # Create artifact attestations
    outputs:
      artifact-id: ${{ steps.upload.outputs.artifact-id }}
    steps:
      # SECURITY: All actions pinned to full SHA-256 commit hashes
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          # SECURITY: Fetch full history to validate tag points to signed commit
          fetch-depth: 0
          persist-credentials: false

      # SECURITY: Verify tag signature if commit signing enforced
      - name: Verify tag signature
        run: |
          git verify-tag ${{ github.ref_name }} || {
            echo "::error::Tag signature verification failed"
            exit 1
          }

      - name: Set up build environment
        uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci  # Reproducible builds from lock file

      # SECURITY: Run tests before building release artifacts
      - name: Run tests
        run: npm test

      - name: Build release artifacts
        run: npm run build

      # SECURITY: Generate checksums for artifact integrity verification
      - name: Generate checksums
        run: |
          cd dist/
          sha256sum * > SHA256SUMS.txt

      # SECURITY: Upload artifacts with attestation
      # Attestation provides cryptographic proof of artifact origin
      - name: Upload artifacts
        id: upload
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: release-artifacts
          path: |
            dist/*
            dist/SHA256SUMS.txt
          retention-days: 90  # Long retention for releases

      # SECURITY: Attest artifact provenance
      # Creates SLSA provenance linking artifact to source and build
      - name: Attest artifacts
        uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-path: 'dist/*'

  # Job 2: Create GitHub release with signed artifacts
  release:
    needs: build
    runs-on: ubuntu-latest
    # SECURITY: Environment protection with approval gate
    environment:
      name: production
      url: https://github.com/${{ github.repository }}/releases/tag/${{ github.ref_name }}
    permissions:
      contents: write     # Create release
      attestations: write # Attach attestations to release
    steps:
      - name: Download artifacts
        uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16  # v4.1.8
        with:
          name: release-artifacts
          path: dist/

      # SECURITY: Verify checksums before release
      - name: Verify artifact checksums
        run: |
          cd dist/
          sha256sum -c SHA256SUMS.txt

      # SECURITY: Create release with generated notes and signed artifacts
      - name: Create GitHub Release
        uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          # SECURITY: Generate release notes from commits between tags
          generate_release_notes: true
          # Attach signed artifacts
          files: |
            dist/*
            dist/SHA256SUMS.txt
          # SECURITY: Mark pre-releases for non-stable versions
          prerelease: ${{ contains(github.ref_name, '-rc') || contains(github.ref_name, '-beta') }}
          # Fail if release already exists (prevents overwrites)
          fail_on_unmatched_files: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # Job 3: Verify release integrity (post-release validation)
  verify:
    needs: release
    runs-on: ubuntu-latest
    permissions:
      contents: read
      attestations: read  # Verify attestations
    steps:
      - name: Download release artifacts
        run: |
          gh release download ${{ github.ref_name }} \
            --repo ${{ github.repository }} \
            --dir verification/
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Verify checksums
        run: |
          cd verification/
          sha256sum -c SHA256SUMS.txt

      # SECURITY: Verify attestations using GitHub CLI
      - name: Verify attestations
        run: |
          cd verification/
          for file in *; do
            [[ "$file" == "SHA256SUMS.txt" ]] && continue
            echo "Verifying attestation for $file"
            gh attestation verify "$file" \
              --repo ${{ github.repository }} \
              --owner ${{ github.repository_owner }}
          done
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Permissions**: `id-token: write` and `attestations: write` for signing, `contents: write` for release creation.

### Advanced Release with SLSA Provenance

Complete release workflow with SLSA L3 provenance generation using official SLSA generators.

```yaml
name: SLSA L3 Release
on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read

jobs:
  # Job 1: Build with SLSA provenance generator
  # SECURITY: Uses official SLSA generator (isolated build with provenance)
  build:
    permissions:
      id-token: write   # Generate OIDC tokens
      contents: write   # Upload assets to release
      actions: read     # Read workflow metadata
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.0.0
    with:
      # SECURITY: Build command runs in isolated environment
      compile-generator: true
      # Artifact paths to attest
      base64-subjects: |
        {
          "name": "binary-linux-amd64",
          "digest": {
            "sha256": "${{ needs.build-binary.outputs.hash-linux-amd64 }}"
          }
        }

  # Job 2: Build actual release artifacts
  build-binary:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      hash-linux-amd64: ${{ steps.hash.outputs.hash-linux-amd64 }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-go@93397bea11091df50f3d7e59dc26a7711a8bcfbe  # v4.1.0
        with:
          go-version: '1.22'
          cache: true

      # SECURITY: Reproducible build with -trimpath
      - name: Build binary
        run: |
          go build -trimpath -ldflags="-s -w \
            -X main.version=${{ github.ref_name }} \
            -X main.commit=${{ github.sha }} \
            -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            -o binary-linux-amd64 .

      # SECURITY: Generate hash for provenance
      - name: Generate hash
        id: hash
        run: |
          echo "hash-linux-amd64=$(sha256sum binary-linux-amd64 | cut -d' ' -f1)" >> "$GITHUB_OUTPUT"

      - name: Upload binary
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: binary-linux-amd64
          path: binary-linux-amd64
          retention-days: 90

  # Job 3: Create release with SLSA provenance
  release:
    needs: [build, build-binary]
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: write
    steps:
      - name: Download binary
        uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16  # v4.1.8
        with:
          name: binary-linux-amd64

      # SECURITY: Download SLSA provenance from generator
      - name: Download provenance
        uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16  # v4.1.8
        with:
          name: binary-linux-amd64.intoto.jsonl

      - name: Create release
        uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          generate_release_notes: true
          files: |
            binary-linux-amd64
            binary-linux-amd64.intoto.jsonl
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**SLSA Level**: L3 (isolated build with provenance generation via reusable workflow).

## Container Release Workflow

Secure workflow for building and releasing OCI containers with provenance and SBOM.

### Signed Container Release

Build and push container images with SLSA provenance and SBOM attestations.

```yaml
name: Secure Container Release
on:
  push:
    tags:
      - 'v*.*.*'

permissions:
  contents: read

jobs:
  # Job 1: Build and push container with attestations
  build-container:
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: read
      packages: write      # Push to GitHub Container Registry
      id-token: write      # Sign with OIDC
      attestations: write  # Create provenance/SBOM
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Log in to GHCR using GITHUB_TOKEN (no long-lived credentials)
      - name: Log in to GitHub Container Registry
        uses: docker/login-action@343f7c4344506bcbf9b4de18042ae17996df046d  # v3.0.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # SECURITY: Extract metadata for tags and labels
      - name: Extract container metadata
        id: meta
        uses: docker/metadata-action@8e5442c4ef9f78752691e2d8f8d19755c6f78e81  # v5.5.1
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
          node-version: '20'
          registry-url: 'https://npm.pkg.github.com'
          scope: '@${{ github.repository_owner }}'

      - run: npm ci
      - run: npm run build

      # SECURITY: Update package.json for GitHub Packages
      - name: Configure package for GitHub Packages
        run: |
          jq '.name = "@${{ github.repository_owner }}/" + .name' package.json > package.json.tmp
          mv package.json.tmp package.json

      - name: Publish to GitHub Packages
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # Job 3: Create GitHub release
  release:
    needs: [publish-npm, publish-github]
    runs-on: ubuntu-latest
    environment: production
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - name: Create GitHub release
        uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          generate_release_notes: true
          body: |
            ## NPM Package

            Install via npm:
            ```bash
            npm install ${{ github.event.repository.name }}@${{ github.ref_name }}
            ```

            Install via GitHub Packages:
            ```bash
            npm install @${{ github.repository_owner }}/${{ github.event.repository.name }}@${{ github.ref_name }}
            ```

            ### Provenance Verification

            Verify package provenance:
            ```bash
            npm audit signatures
            ```
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Provenance**: npm CLI automatically generates and publishes provenance statements when `--provenance` flag used.

## Security Checklist

Use this checklist to verify your release workflow follows security best practices.

### Release Security

- [ ] Releases triggered only by version tags (`v*.*.*`)
- [ ] Tag signatures verified if commit signing enforced
- [ ] Environment protection with approval gate for production releases
- [ ] Pre-release flag set for non-stable versions (beta, rc)
- [ ] Release notes auto-generated from commit history
- [ ] Checksums generated for all release artifacts

### Action Security

- [ ] All third-party actions pinned to full SHA-256 commit hashes
- [ ] Version comments added for human readability (`# vX.Y.Z`)
- [ ] Dependabot configured to update action pins
- [ ] Actions from verified publishers or GitHub-maintained only
- [ ] SLSA generator used for L3 provenance (if applicable)

### Permission Security

- [ ] Workflow-level permissions set to minimal (`contents: read`)
- [ ] `id-token: write` only on jobs that sign/attest
- [ ] `attestations: write` only on jobs that create attestations
- [ ] `contents: write` only on release creation job
- [ ] `packages: write` only on container/package publish jobs
- [ ] No `permissions: write-all` or default write permissions

### Artifact Security

- [ ] Artifact attestations created for all release artifacts
- [ ] SLSA provenance generated (L2 minimum, L3 preferred)
- [ ] Checksums (SHA-256) generated for artifact integrity
- [ ] Artifacts uploaded with long retention (90 days for releases)
- [ ] SBOM generated for containers and dependencies
- [ ] Container images scanned for vulnerabilities before release

### Signing and Verification

- [ ] Artifacts signed with OIDC (keyless signing)
- [ ] Container images signed with Cosign
- [ ] NPM packages published with `--provenance` flag
- [ ] Signatures pushed to transparency log (Rekor)
- [ ] Verification instructions included in release notes
- [ ] Post-release verification job validates signatures

### Distribution Security

- [ ] Container images pushed to GHCR (no Docker Hub)
- [ ] Multi-architecture manifests created for containers
- [ ] NPM packages published to both npm and GitHub Packages
- [ ] Registry authentication via OIDC (no long-lived tokens)
- [ ] Package scopes configured correctly
- [ ] Public packages marked as `--access public`

## Common Mistakes and Fixes

### Mistake 1: Missing Attestations Permissions

**Bad**:

```yaml
# DANGER: Attestation creation will fail without id-token and attestations permissions
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/attest-build-provenance@v1
        with:
          subject-path: 'dist/*'
```

**Good**:

```yaml
# SECURITY: Grant id-token and attestations permissions for signing
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write      # Generate OIDC tokens for signing
      attestations: write  # Create attestations
    steps:
      - uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-path: 'dist/*'
```

### Mistake 2: Unverified Release Artifacts

**Bad**:

```yaml
# DANGER: No checksum verification before release
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
      - uses: softprops/action-gh-release@v0.1.15
        with:
          files: 'dist/*'
```

**Good**:

```yaml
# SECURITY: Verify checksums before releasing artifacts
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16  # v4.1.8
        with:
          name: release-artifacts
          path: dist/

      # SECURITY: Verify artifact integrity
      - name: Verify checksums
        run: |
          cd dist/
          sha256sum -c SHA256SUMS.txt

      - uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          files: 'dist/*'
```

### Mistake 3: Container Images Without Provenance

**Bad**:

```yaml
# DANGER: No provenance or SBOM for container image
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/org/image:latest
```

**Good**:

```yaml
# SECURITY: Enable provenance and SBOM for supply chain security
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      id-token: write
      attestations: write
    steps:
      - uses: docker/build-push-action@4a13e500e55cf31b7a5d59a38ab2040ab0f42f56  # v5.1.0
        id: push
        with:
          push: true
          tags: ghcr.io/org/image:${{ github.ref_name }}
          provenance: true  # SLSA provenance
          sbom: true        # Software Bill of Materials

      # SECURITY: Attest container with GitHub attestations
      - uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-name: ghcr.io/org/image
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

### Mistake 4: NPM Publish Without Provenance

**Bad**:

```yaml
# DANGER: NPM package published without provenance
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/setup-node@v3
        with:
          registry-url: 'https://registry.npmjs.org'
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**Good**:

```yaml
# SECURITY: Publish with provenance for supply chain transparency
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Generate provenance
    steps:
      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          registry-url: 'https://registry.npmjs.org'

      # SECURITY: --provenance flag generates and publishes provenance
      - run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Mistake 5: No Environment Protection for Releases

**Bad**:

```yaml
# DANGER: No approval gate for production releases
on:
  push:
    tags: ['v*.*.*']

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: softprops/action-gh-release@v0.1.15
```

**Good**:

```yaml
# SECURITY: Require approval before production releases
on:
  push:
    tags: ['v*.*.*']

jobs:
  release:
    runs-on: ubuntu-latest
    # SECURITY: Environment protection with required reviewers
    environment:
      name: production
      url: https://github.com/${{ github.repository }}/releases/tag/${{ github.ref_name }}
    permissions:
      contents: write
    steps:
      - uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          generate_release_notes: true
```

## Related Patterns

- **[Action Pinning](../action-pinning/sha-pinning.md)**: SHA pinning patterns and Dependabot configuration
- **[Token Permissions](../token-permissions/templates.md)**: GITHUB_TOKEN permission templates for all workflow types
- **[Environment Protection](../workflows/environments.md)**: Deployment gates and approval workflows
- **[Secret Management](../secrets/oidc.md)**: OIDC patterns for keyless signing and cloud authentication
- **[Third-Party Actions](../third-party-actions/common-actions.md)**: Security review of release-related actions

## Summary

Secure release workflows require comprehensive attestation and verification:

1. **Pin all actions** to SHA-256 hashes with version comments
2. **Minimize permissions** with `id-token: write` and `attestations: write` only where needed
3. **Generate attestations** for all release artifacts (binaries, containers, packages)
4. **Create SLSA provenance** at L2 minimum, L3 preferred for critical releases
5. **Sign artifacts** with keyless signing (Cosign, npm provenance)
6. **Verify artifacts** post-release with checksums and attestation verification
7. **Require approvals** via environment protection for production releases
8. **Include verification instructions** in release notes for users

Copy these templates as starting points for your release workflows. Adjust signing methods and distribution channels based on your artifact types and security requirements.
