---
title: Package Release and Security Checklist
description: >-
  NPM package releases with provenance, security checklist for artifact attestations, and common release workflow mistakes to avoid
---

!!! warning "Verify Before Release"

    Release workflows publish to public registries. Verify artifact checksums, provenance generation, and signature verification instructions before tagging releases. Published packages cannot be deleted.

## NPM Package Release

```yaml
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

- [ ] Container images pushed to GHCR or cloud-native artifact registries
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

## Mistake 2: Unverified Release Artifacts

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
      - name: Build container
        run: |
          buildah build --tag ghcr.io/org/image:latest .
          buildah push ghcr.io/org/image:latest
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
      - name: Build container with buildah
        id: build
        run: |
          IMAGE="ghcr.io/org/image:${{ github.ref_name }}"

          # Build with OCI-compliant tooling
          buildah build \
            --tag "${IMAGE}" \
            --label org.opencontainers.image.version="${{ github.ref_name }}" \
            .

          # Push to registry
          buildah push "${IMAGE}"

          # Get digest for attestation
          DIGEST=$(buildah inspect "${IMAGE}" | jq -r '.Digest')
          echo "digest=${DIGEST}" >> $GITHUB_OUTPUT

      # SECURITY: Attest container with GitHub attestations
      - uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-name: ghcr.io/org/image
          subject-digest: ${{ steps.build.outputs.digest }}
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

- **[Action Pinning](../../action-pinning/sha-pinning.md)**: SHA pinning patterns and Dependabot configuration
- **[Token Permissions](../../token-permissions/templates.md)**: GITHUB_TOKEN permission templates for all workflow types
- **[Environment Protection](../../workflows/environments/index.md)**: Deployment gates and approval workflows
- **[Secret Management](../../secrets/oidc/index.md)**: OIDC patterns for keyless signing and cloud authentication
- **[Third-Party Actions](../../third-party-actions/common-actions.md)**: Security review of release-related actions

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
