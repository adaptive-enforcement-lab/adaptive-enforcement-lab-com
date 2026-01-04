---
title: Advanced SLSA Patterns for Node.js
tags:
  - slsa
  - provenance
  - node
  - nodejs
  - npm
  - containers
  - docker
  - supply-chain
  - security
  - attestation
  - developers
  - operators
description: >-
  Advanced SLSA patterns for Node.js: provenance verification with slsa-verifier, container deployment patterns, common gotchas, and production best practices.
---
# Advanced SLSA Patterns for Node.js

Verification workflows, deployment gates, and production best practices.

!!! info "Prerequisites"
    Read [Node.js Integration](node-integration.md) first for core build patterns. This guide covers advanced scenarios.

---

## Verification

Verify npm package provenance with `slsa-verifier`:

```bash
# Download package and provenance
npm pack @org/package@1.0.0
gh release download v1.0.0 --pattern '*.intoto.jsonl'

# Verify provenance
slsa-verifier verify-artifact org-package-1.0.0.tgz \
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
  --source-uri github.com/org/repo
```

**Integration with deployment**:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: slsa-framework/slsa-verifier/actions/installer@v2.6.0

      - name: Verify image provenance
        run: |
          slsa-verifier verify-image \
            ghcr.io/${{ github.repository }}:${{ inputs.tag }} \
            --source-uri "github.com/${{ github.repository }}"

      - name: Deploy to Kubernetes
        run: kubectl set image deployment/app app=ghcr.io/${{ github.repository }}:${{ inputs.tag }}
```

---

## npm Registry Provenance Verification

npm's native `--provenance` flag publishes attestations to the npm registry. Verify them:

```bash
# Install package with signature verification
npm install --audit-signatures @org/package

# Audit all installed package signatures
npm audit signatures
```

**CI integration**:

```yaml
- name: Verify npm registry provenance
  run: |
    npm install --audit-signatures
    npm audit signatures --audit-level=moderate
```

**Combined approach**: Use both npm registry provenance AND SLSA GitHub provenance for defense-in-depth.

---

## Common Node-Specific Gotchas

| Issue | Symptom | Fix |
|-------|---------|-----|
| Lockfile drift | CI builds fail with "lockfile out of sync" | Always use `npm ci` instead of `npm install` |
| Dev dependencies in production | Large bundle sizes, security risks | Use `npm ci --omit=dev` for production builds |
| Node version mismatch | Build succeeds in CI, fails in deployment | Pin Node version with `.nvmrc` and `node-version-file` |
| npm audit vulnerabilities | Failing builds on security advisories | Run `npm audit --audit-level=high` in CI |
| Missing build artifacts | Provenance generated but no dist/ folder | Ensure `npm run build` completes before provenance generation |
| npm publish --provenance fails | "id-token: write permission required" | Add `id-token: write` to workflow permissions |
| Tarball size mismatch | Provenance hash doesn't match artifact | Check `.npmignore` or `files` in package.json |

---

## Best Practices

**Always use `npm ci`**: Enforces lockfile integrity, faster than `npm install`. Critical for reproducible builds.

**Commit lockfiles**: `package-lock.json`, `yarn.lock`, or `pnpm-lock.yaml` must be in version control.

**Pin Node versions**: Use `.nvmrc` or `package.json#engines` for consistency across environments.

**Separate build artifacts**: Generate provenance for tarballs or bundled output, not raw source files.

**Use multi-stage container builds**: Separate build and runtime stages for smaller images, fewer vulnerabilities.

**Verify before publish**: Run `npm audit` and vulnerability scans before provenance generation.

**Automate npm provenance**: Use `npm publish --provenance` for native npm registry support.

**Fail closed on verification**: Block deployments if provenance verification fails. Never deploy unverified artifacts.

**Verify both npm and GitHub**: Use `npm audit signatures` for registry provenance, `slsa-verifier` for GitHub provenance.

**Pin SLSA generator versions**: Use exact version tags (`@v2.1.0`), not floating tags (`@main`).

---

## Deployment Gate Pattern

Block deployments until provenance verification succeeds:

```yaml
jobs:
  verify-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: package

      - name: Download provenance
        run: gh release download ${{ inputs.tag }} --pattern '*.intoto.jsonl'

      - uses: slsa-framework/slsa-verifier/actions/installer@v2.6.0

      - name: Verify provenance (blocking)
        run: |
          slsa-verifier verify-artifact *.tgz \
            --provenance-path *.intoto.jsonl \
            --source-uri "github.com/${{ github.repository }}" \
            || exit 1

      - name: Deploy only if verified
        run: |
          echo "Provenance verified. Deploying..."
          npm publish *.tgz
```

**Critical**: The `|| exit 1` ensures deployment never proceeds if verification fails.

---

## Integration Checklist

Before deploying Node.js applications with SLSA provenance:

- [ ] Lockfile committed (`package-lock.json`, `yarn.lock`, or `pnpm-lock.yaml`)
- [ ] CI uses `npm ci` instead of `npm install`
- [ ] Node version pinned with `.nvmrc` or `node-version-file`
- [ ] Build artifacts packaged (tarball, container image, or bundled JS)
- [ ] Provenance generated with `slsa-github-generator`
- [ ] npm packages use `npm publish --provenance`
- [ ] Container images use multi-stage builds
- [ ] Verification automated in deployment workflow
- [ ] Renovate configured to skip SHA pins for slsa-github-generator
- [ ] Deployment gates verify provenance before kubectl/npm publish
- [ ] npm audit signatures enabled for registry provenance
- [ ] Fail-closed verification (block deployments on failure)

---

## Troubleshooting

### npm publish --provenance Fails

**Cause**: Missing `id-token: write` permission or npm token misconfiguration

**Fix**: Ensure workflow has `id-token: write` and `NODE_AUTH_TOKEN` is set to npm automation token (not classic token).

```yaml
permissions:
  id-token: write
  contents: read
```

### Verification Fails with "source URI mismatch"

**Cause**: Built from fork or different repository

**Fix**: Verify `--source-uri` matches actual build repository. Check for fork confusion.

```bash
# Check provenance source
jq -r '.predicate.buildConfig.source_uri' provenance.intoto.jsonl
```

### Lockfile Out of Sync

**Cause**: Local `npm install` modified lockfile, not committed

**Fix**: Run `npm ci` locally to verify lockfile. Commit changes if valid. Always use `npm ci` in CI.

```bash
# Verify lockfile locally
npm ci --dry-run
```

### Container Image Build Fails

**Cause**: Containerfile expects dev dependencies, but using `--omit=dev`

**Fix**: Run `npm ci` (all deps) in build stage, `--omit=dev` only for production stage.

```dockerfile
# Build stage - all dependencies
RUN npm ci

# Production stage - runtime only
RUN npm ci --omit=dev
```

### slsa-verifier Not Found

**Cause**: Tool not installed in deployment environment

**Fix**: Use `slsa-framework/slsa-verifier/actions/installer@v2.6.0` in GitHub Actions.

### npm audit signatures Fails

**Cause**: Package published without `--provenance` flag

**Fix**: Republish package with `npm publish --provenance`. Requires npm 9.5.0+.

---

## FAQ

**Can I use SLSA with private npm packages?** Yes. SLSA verifies build integrity, not package visibility. Private packages work normally.

**Does npm publish --provenance replace SLSA?** No. npm's `--provenance` publishes to npm registry. SLSA provenance adds GitHub Releases attestation. Use both for defense-in-depth.

**What about Yarn v2/v3 (Berry)?** Works with generic SLSA pattern. No native `--provenance` flag yet. Use Pattern 1 from [Node.js Integration](node-integration.md).

**Can I use pnpm?** Yes. Use generic SLSA pattern with `pnpm pack` for tarball generation. No native provenance support yet.

**How do I verify npm registry provenance?** Use `npm audit signatures` for npm registry provenance. Use `slsa-verifier` for GitHub Releases provenance. Verify both.

**Does SLSA work with monorepos?** Yes. Generate provenance per workspace package or for root-level builds. Use `npm pack --workspace=<name>`.

**What about TypeScript builds?** Works perfectly. Generate provenance for compiled JavaScript output (`dist/` folder), not TypeScript source.

**Can I verify provenance locally?** Yes. Install `slsa-verifier` CLI and verify downloaded artifacts before deployment.

**What npm version is required?** `npm publish --provenance` requires npm 9.5.0+. SLSA provenance works with any npm version.

**How do I handle monorepo publishes?** Generate separate provenance for each workspace package:

```bash
npm pack --workspace=package-a
npm pack --workspace=package-b
# Generate provenance for each tarball
```

---

## Related Content

- **[Node.js Integration](node-integration.md)**: Core build patterns
- **[SLSA Implementation Playbook](../index.md)**: Complete adoption guide
- **[Verification Workflows](../verification-workflows.md)**: Automate provenance verification
- **[Policy Templates](../policy-templates.md)**: Kyverno and OPA policies for enforcement
- **[Runner Configuration](../runner-configuration.md)**: Self-hosted vs GitHub-hosted considerations

---

*Verification turns provenance from evidence to enforcement.*
