---
title: GITHUB_TOKEN Permission Templates
description: >-
  Copy-paste ready permission blocks for common workflow types. CI, release, deployment, documentation, and security scanning templates with minimal permissions.
tags:
  - github-actions
  - security
  - github-token
  - permissions
  - templates
---

# GITHUB_TOKEN Permission Templates

Copy-paste ready permission blocks for common workflow types. Start with minimal permissions, add only what's required.

!!! tip "Template Usage"

    Copy the entire workflow template for your use case. Permissions are pre-configured for least privilege. Adjust only if your workflow requires additional API access.

## CI/Test Workflow

Standard continuous integration workflow for testing, linting, and building code.

### Basic CI Template

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm test
```

**Permissions**: `contents: read` for checkout only. No write access.

### CI with PR Comments

Post test results or coverage reports as PR comments.

```yaml
name: CI with Coverage
on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
      - run: npm ci
      - run: npm test -- --coverage

      - uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            const fs = require('fs');
            const coverage = fs.readFileSync('coverage/summary.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Coverage\n\n\`\`\`\n${coverage}\n\`\`\``
            });
```

**Permissions**: `pull-requests: write` scoped to job that posts comments. Read-only for test job.

## Release Workflow

Create GitHub releases and push tags.

### Basic Release

```yaml
name: Release
on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - run: |
          npm ci
          npm run build

      - uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          files: dist/*
          generate_release_notes: true
```

**Permissions**: `contents: write` for creating releases and uploading assets.

**Security Note**: Protect release tags with branch protection requiring signed commits.

### Release with Package Publishing

```yaml
name: Release and Publish
on:
  push:
    tags: ['v*']

permissions:
  contents: write
  packages: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
          registry-url: 'https://npm.pkg.github.com'

      - run: npm ci
      - run: npm run build
      - run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
        with:
          generate_release_notes: true
```

**Permissions**: `contents: write` for releases, `packages: write` for GitHub Packages.

## Deployment Workflow

Deploy using OIDC federation for cloud authentication.

### GCP Deployment with Workload Identity

```yaml
name: Deploy to GCP
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v1.1.1
        with:
          workload_identity_provider: 'projects/123/locations/global/workloadIdentityPools/github/providers/github'
          service_account: 'github-actions@my-project.iam.gserviceaccount.com'

      - run: |
          gcloud run deploy my-service \
            --source . \
            --region us-central1 \
            --platform managed
```

**Permissions**: `id-token: write` for OIDC token, `contents: read` for checkout.

**Security**: No long-lived credentials. Token is ephemeral and scoped to workflow run.

## Documentation Workflow

Build and deploy documentation to GitHub Pages.

```yaml
name: Deploy Documentation
on:
  push:
    branches: [main]

permissions:
  contents: read
  pages: write
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: actions/setup-python@65d7f2d534ac1bc67fcd62888c5f4f3d2cb2b236  # v4.7.1
        with:
          python-version: '3.11'

      - run: pip install mkdocs-material
      - run: mkdocs build

      - uses: actions/upload-pages-artifact@0252fc4ba7626f0298f0cf00902a25c6afc77fa8  # v2.0.0
        with:
          path: 'site'

      - id: deployment
        uses: actions/deploy-pages@9dbe3824824f8a1377b8e298bafde1a50ede43e5  # v2.0.1
```

**Permissions**: `pages: write` for deployment, `id-token: write` for verification, `contents: read` for checkout.

**Requires**: GitHub Pages configured with "GitHub Actions" as source.

## Security Scanning Workflow

Run security scans and upload results to GitHub Security tab.

```yaml
name: Security Scan
on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * *'

permissions:
  contents: read
  security-events: write

jobs:
  codeql:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - uses: github/codeql-action/init@e8893c57a1f3a2b659b6b55564fdfdbbd2982911  # v3.24.0
        with:
          languages: javascript
      - uses: github/codeql-action/autobuild@e8893c57a1f3a2b659b6b55564fdfdbbd2982911  # v3.24.0
      - uses: github/codeql-action/analyze@e8893c57a1f3a2b659b6b55564fdfdbbd2982911  # v3.24.0

  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - uses: aquasecurity/trivy-action@2b6a709cf9c4025c5438138008beaddbb02086f0  # v0.14.0
        with:
          scan-type: 'fs'
          format: 'sarif'
          output: 'trivy-results.sarif'
      - uses: github/codeql-action/upload-sarif@e8893c57a1f3a2b659b6b55564fdfdbbd2982911  # v3.24.0
        with:
          sarif_file: 'trivy-results.sarif'
```

**Permissions**: `security-events: write` for uploading SARIF to Security tab.

## Quick Reference

| Workflow Type | Permissions | Use Case |
| ------------- | ----------- | -------- |
| **CI/Test** | `contents: read` | Test, lint, build |
| **PR Comment** | `contents: read`<br>`pull-requests: write` | Post results to PR |
| **Security Scan** | `contents: read`<br>`security-events: write` | Upload SARIF |
| **Release** | `contents: write` | Create releases |
| **Package Publish** | `contents: read`<br>`packages: write` | Publish packages |
| **Cloud Deploy (OIDC)** | `id-token: write`<br>`contents: read` | OIDC federation |
| **GitHub Pages** | `contents: read`<br>`pages: write`<br>`id-token: write` | Deploy docs |

## Multi-Job Patterns

Different jobs need different permissions. Scope at job level for least privilege.

```yaml
name: CI with Release
on:
  push:
    branches: [main]
    tags: ['v*']

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - run: npm ci
      - run: npm test

  release:
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - run: npm ci && npm run build
      - uses: softprops/action-gh-release@de2c0eb89ae2a093876385947365aca7b0e5f844  # v0.1.15
```

**Pattern**: Test job is read-only. Release job escalates to `contents: write` only when triggered by tag.

## Best Practices

- **Always specify explicit permissions** - Never rely on repository defaults
- **Start minimal, escalate as needed** - Begin with `contents: read`, add on error
- **Scope to job when possible** - Use job-level permissions for mixed workflows
- **Prefer OIDC over secrets** - Use `id-token: write` instead of long-lived credentials
- **Avoid `contents: write`** - Enables workflow self-modification

## Next Steps

- **[Job-Level Scoping](job-scoping.md)**: Advanced patterns for multi-job workflows
- **[Complete Examples](../examples/index.md)**: Production workflows with all security patterns
- **[Permissions Overview](index.md)**: Return to permissions matrix

---

!!! success "Copy-Paste Ready"

    All templates are production-ready. Copy entire workflows and adjust for your use case. Permissions are pre-configured for least privilege.
