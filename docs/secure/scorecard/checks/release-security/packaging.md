---
description: >-
  Complete remediation guide for OpenSSF Scorecard Packaging check.
  Publish to package registries for wider distribution and trust.
tags:
  - scorecard
  - packaging
  - registries
---

# Packaging Check

**Target**: 10/10 by publishing to package manager

**What it checks**: Whether project is published to language-specific package manager (npm, PyPI, Go modules, RubyGems, Maven Central, crates.io, NuGet).

**Why it matters**: Package managers provide centralized distribution, version management, and dependency resolution. Publishing signals production-ready code and makes consumption easier for users.

### Understanding the Score

Scorecard detects:

- Package registry metadata (npm, PyPI, Go, etc.)
- GitHub Release artifacts matching package names
- Automated publishing workflows

**Scoring**:

- **10/10**: Package published to appropriate registry for project language
- **0/10**: No package registry detected

**Note**: This check is binary (0 or 10). You either publish packages or you don't.

### Before: GitHub Releases Only

```text
Distribution method: GitHub Releases

Users must:
1. Navigate to Releases page
2. Download platform-specific binary
3. Manually install to PATH
4. Manually track updates
```

**Scorecard result**: Packaging 0/10

### After: Package Manager Distribution

#### Go Modules (Implicit Publishing)

Go modules are published automatically via git tags:

```bash
# Tag release
git tag v1.2.3
git push origin v1.2.3

# Users can install directly
go install github.com/your-org/your-cli@v1.2.3
```

**No workflow needed** - Go proxy fetches from GitHub tags automatically.

**Scorecard result**: Packaging 10/10

#### npm (Automated Publishing)

```yaml
name: Publish to npm

on:
  release:
    types: [created]

permissions: {}

jobs:
  publish:
    permissions:
      contents: read
      id-token: write  # npm provenance
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: actions/setup-node@1e60f620b9541d16bece96c5465dc8ee9832be0b  # v4.0.3
        with:
          node-version: 20
          registry-url: https://registry.npmjs.org/

      - run: npm ci
      - run: npm publish --provenance --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**Scorecard result**: Packaging 10/10

**Bonus**: `--provenance` flag generates npm provenance attestations (similar to SLSA).

#### Python (PyPI)

```yaml
name: Publish to PyPI

on:
  release:
    types: [created]

permissions: {}

jobs:
  publish:
    permissions:
      contents: read
      id-token: write  # OIDC for Trusted Publishing
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.11'

      - name: Build package
        run: |
          pip install build
          python -m build

      - uses: pypa/gh-action-pypi-publish@ec4db0b4ddc65acdf4bff5fa45ac92d78b56bdf0  # v1.9.0
        with:
          repository-url: https://upload.pypi.org/legacy/
```

**Scorecard result**: Packaging 10/10

**Note**: PyPI supports Trusted Publishing (OIDC) - no long-lived tokens needed.

#### Container Registries

```yaml
name: Publish to GHCR

on:
  release:
    types: [created]

permissions: {}

jobs:
  publish:
    permissions:
      contents: read
      packages: write
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4

      - uses: docker/login-action@9780b0c442fbb1117ed29e0efdff1e18412f7567  # v3.3.0
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@5176d81f87c23d6fc96624dfdbcd9f3830bbe445  # v6.5.0
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}:latest
```

**Scorecard result**: Packaging 10/10

### Packaging Best Practices

#### 1. Semantic Versioning

Use semantic versioning for package releases:

```text
v1.2.3
 │ │ └─ Patch (bug fixes)
 │ └─── Minor (new features, backwards compatible)
 └───── Major (breaking changes)
```

#### 2. Package Provenance

Language ecosystems support provenance:

- **npm**: `npm publish --provenance` (requires OIDC)
- **PyPI**: Trusted Publishing via GitHub OIDC
- **Go**: Transparent checksum database (sum.golang.org)
- **Container images**: SLSA provenance for container builds

#### 3. Automated Publishing

Never publish manually:

```yaml
# GOOD - automated on release
on:
  release:
    types: [created]

# BAD - manual publishing from developer machine
# $ npm publish  (run locally)
```

**Why**: Automated publishing ensures:

- Reproducible builds
- No developer credentials in packages
- Audit trail via workflow logs
- OIDC-based authentication (no long-lived tokens)

#### 4. Version Consistency

Keep package version in sync with git tags:

```json
// package.json
{
  "name": "your-package",
  "version": "1.2.3"  // Must match git tag v1.2.3
}
```

Automate version bumping:

```yaml
- name: Update package version
  run: |
    VERSION=${GITHUB_REF#refs/tags/v}
    npm version $VERSION --no-git-tag-version
```

### Troubleshooting

#### Issue: Scorecard doesn't detect published package

**Cause**: Package name mismatch or registry not scanned.

**Fix**: Ensure package name matches repository and is published to supported registry (npm, PyPI, Maven, RubyGems, crates.io, NuGet, Go modules).

#### Issue: Publishing fails with authentication error

**Cause**: Missing or invalid token.

**Fix for npm**:

1. Generate token at npmjs.com
2. Add as `NPM_TOKEN` secret in repository
3. Use in workflow: `NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}`

**Fix for PyPI** (Trusted Publishing):

1. Configure Trusted Publisher in PyPI project settings
2. Add workflow name, environment (if used), and repository
3. Use OIDC in workflow (no token needed)

#### Issue: Version conflict on publish

**Cause**: Version already exists in registry.

**Fix**: Package registries are immutable. Increment version for new release.

### Remediation Steps

**Time estimate**: 1 to 2 hours (initial setup), automatic afterwards

**Step 1: Choose registry** (15 minutes)

Select appropriate package manager for your language:

- JavaScript/TypeScript → npm
- Python → PyPI
- Go → Go modules (automatic via git tags)
- Rust → crates.io
- Java → Maven Central
- Ruby → RubyGems
- .NET → NuGet
- Containers → GHCR, GCR, Artifact Registry

**Step 2: Configure credentials** (30 minutes)

**For npm**:

1. Create account at npmjs.com
2. Generate automation token (Account → Access Tokens → Generate New Token → Automation)
3. Add `NPM_TOKEN` secret to repository

**For PyPI** (Trusted Publishing - recommended):

1. Create account at pypi.org
2. Configure Trusted Publisher in project settings:
   - Owner: `your-org`
   - Repository: `your-repo`
   - Workflow: `publish.yml`
   - Environment: (leave blank or specify)

**For Go**: No credentials needed (uses git tags)

**Step 3: Create publish workflow** (30 minutes)

Add `.github/workflows/publish.yml`:

```yaml
name: Publish Package

on:
  release:
    types: [created]

permissions: {}

jobs:
  publish:
    permissions:
      contents: read
      id-token: write
    runs-on: ubuntu-latest
    steps:
      # See language-specific examples above
```

**Step 4: Test with pre-release** (30 minutes)

Create test release:

```bash
git tag v0.0.1-beta.1
git push origin v0.0.1-beta.1
gh release create v0.0.1-beta.1 --prerelease
```

Verify publishing:

```bash
# npm
npm view your-package@0.0.1-beta.1

# PyPI
pip index versions your-package

# Go
go install github.com/your-org/your-cli@v0.0.1-beta.1
```

**Step 5: Validate Scorecard** (15 minutes)

Run Scorecard:

```bash
docker run -e GITHUB_TOKEN=$GITHUB_TOKEN gcr.io/openssf/scorecard:stable \
  --repo=github.com/your-org/your-repo --show-details | grep Packaging
```

Expected: **Packaging 10/10**

---

## Related Content

- [Signed-Releases](./signed-releases.md) | [License](./license.md) | [Scorecard Index](../../index.md)

---

*Packaging demonstrates wider distribution. Publishing to package registries increases project visibility and trust.*
