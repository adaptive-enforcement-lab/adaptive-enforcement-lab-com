---
title: Container Release Workflows
description: >-
  Signed container releases with SLSA provenance, Cosign keyless signing, and multi-architecture image build patterns for production
---

!!! note "GHCR Authentication Required"

    These workflows authenticate to GitHub Container Registry using GITHUB_TOKEN. Ensure repository has packages write permission and GHCR is enabled before deploying container release workflows.

```yaml
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=sha,prefix={{branch}}-

      # SECURITY: Build and push with OCI-compliant tooling
      - name: Build container image
        id: build
        run: |
          IMAGE_NAME="ghcr.io/${{ github.repository }}"
          VERSION="${{ github.ref_name }}"

          buildah build \
            --tag "${IMAGE_NAME}:${VERSION}" \
            --build-arg VERSION="${VERSION}" \
            --build-arg COMMIT="${{ github.sha }}" \
            --build-arg BUILD_DATE="${{ github.event.head_commit.timestamp }}" \
            --label org.opencontainers.image.version="${VERSION}" \
            --label org.opencontainers.image.revision="${{ github.sha }}" \
            .

          # Push to registry
          buildah push "${IMAGE_NAME}:${VERSION}"

          # Get digest for attestation
          DIGEST=$(buildah inspect "${IMAGE_NAME}:${VERSION}" | jq -r '.Digest')
          echo "digest=${DIGEST}" >> $GITHUB_OUTPUT

      # SECURITY: Attest container provenance with GitHub attestations
      - name: Attest container image
        uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.build.outputs.digest }}
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

## Key Patterns

**Build and Attestation Flow**:

1. Build container with buildah (OCI-compliant tooling)
2. Push to GHCR with digest-based reference
3. Scan with Trivy for vulnerabilities
4. Sign with Cosign keyless signing (OIDC)
5. Attest with GitHub attestations API

**Security Controls**:

- SHA-pinned actions with version comments
- Minimal GITHUB_TOKEN permissions scoped per job
- Environment protection for production releases
- OIDC authentication to GHCR (no stored credentials)
- Vulnerability scanning before signing
- Provenance and SBOM generation

## Related Patterns

- **[Multi-Architecture Builds](multi-arch-builds.md)**: Build containers for multiple platforms with unified manifests
- **[Package Release Checklist](package-release-checklist.md)**: Security checklist for all release workflows
- **[Action Pinning](../../action-pinning/sha-pinning.md)**: SHA-256 pinning patterns and Dependabot automation
- **[Token Permissions](../../token-permissions/templates.md)**: Permission templates for release workflows
- **[Environment Protection](../../workflows/environments/index.md)**: Deployment gates and approval workflows
- **[OIDC Patterns](../../secrets/oidc/cloud-providers.md)**: Keyless authentication to cloud registries

## Summary

Secure container releases require comprehensive attestation and signing:

1. **Build with OCI-compliant tooling** (buildah, podman) for vendor neutrality
2. **Scan before release** with Trivy or equivalent container scanner
3. **Sign with keyless signing** using OIDC (no long-lived signing keys)
4. **Generate attestations** linking container to source and build provenance
5. **Push to GHCR** with environment protection and approval gates

For multi-architecture support, see [Multi-Architecture Builds](multi-arch-builds.md) for matrix build patterns and manifest list creation.
