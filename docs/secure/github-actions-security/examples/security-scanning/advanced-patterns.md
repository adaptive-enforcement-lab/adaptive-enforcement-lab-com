---
title: Advanced Security Scanning Patterns
description: >-
  Container scanning, multi-tool SARIF aggregation, and scheduled vulnerability scanning
---

## Advanced Security Scanning Patterns

### Container Scanning in CI/CD Pipeline

Complete container security workflow with build-time and runtime scanning.

```yaml
name: Container Security Pipeline
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  # Job 1: Scan Dockerfile for misconfigurations
  dockerfile-scan:
    name: Dockerfile Security Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Trivy scans Dockerfile for misconfigurations
      - name: Scan Dockerfile with Trivy
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          scan-type: 'config'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-dockerfile.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'
          # SECURITY: Detect Dockerfile best practice violations
          scanners: 'config'

      - name: Upload Dockerfile scan results
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'trivy-dockerfile.sarif'
          category: 'trivy-dockerfile'

  # Job 2: Build and scan container image
  image-scan:
    name: Container Image Security Scan
    runs-on: ubuntu-latest
    needs: dockerfile-scan
    permissions:
      contents: read
      security-events: write
      id-token: write  # For OIDC signing
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Build container image with Podman
      - name: Build container image
        run: |
          podman build \
            --tag myapp:${{ github.sha }} \
            --label org.opencontainers.image.revision=${{ github.sha }} \
            --label org.opencontainers.image.source=${{ github.repositoryUrl }} \
            .

      # SECURITY: Scan image filesystem and OS packages
      - name: Scan image with Trivy
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          scan-type: 'image'
          image-ref: 'myapp:${{ github.sha }}'
          format: 'sarif'
          output: 'trivy-image.sarif'
          severity: 'CRITICAL,HIGH'
          # SECURITY: Scan OS packages and application dependencies
          scanners: 'vuln,secret,config'
          # SECURITY: Exit code 1 blocks deployment on vulnerabilities
          exit-code: '1'

      - name: Upload image scan results
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'trivy-image.sarif'
          category: 'trivy-image'

      # SECURITY: Generate SBOM (Software Bill of Materials)
      - name: Generate SBOM
        run: |
          # SECURITY: SBOM tracks all dependencies in container
          podman run --rm \
            -v ./:/work \
            ghcr.io/anchore/syft:latest \
            myapp:${{ github.sha }} \
            -o spdx-json=sbom.spdx.json

      - name: Upload SBOM
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: sbom
          path: sbom.spdx.json
          retention-days: 90

      # SECURITY: Scan SBOM for vulnerabilities
      - name: Scan SBOM with Grype
        run: |
          curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
          grype sbom:sbom.spdx.json -o sarif > grype-results.sarif || true

      - name: Upload Grype SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'grype-results.sarif'
          category: 'grype-sbom'
```

### Multi-Tool SARIF Aggregation

Aggregate multiple security tool results into unified Security tab view.

```yaml
name: Aggregated Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  aggregate-security-scan:
    name: Multi-Tool Security Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'

      # SECURITY: Run multiple SAST tools for comprehensive coverage
      - name: Install dependencies
        run: npm ci

      # Tool 1: CodeQL
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: javascript
          queries: security-extended

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          category: 'codeql-javascript'

      # Tool 2: ESLint with security plugin
      - name: Run ESLint security scan
        run: |
          npm install --save-dev eslint @microsoft/eslint-formatter-sarif
          npx eslint . \
            --ext .js,.ts \
            --format @microsoft/eslint-formatter-sarif \
            --output-file eslint-security.sarif || true

      - name: Upload ESLint SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'eslint-security.sarif'
          category: 'eslint-security'

      # Tool 3: Semgrep for pattern-based SAST
      - name: Run Semgrep scan
        run: |
          pip install semgrep
          semgrep --config=auto --sarif --output=semgrep-results.sarif . || true

      - name: Upload Semgrep SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'semgrep-results.sarif'
          category: 'semgrep'

      # Tool 4: Trivy filesystem scan
      - name: Run Trivy filesystem scan
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-fs.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'trivy-fs.sarif'
          category: 'trivy-filesystem'
```

### Scheduled Vulnerability Scanning

Weekly scheduled scanning to detect newly-disclosed vulnerabilities in existing code.

```yaml
name: Scheduled Security Scan
on:
  schedule:
    # SECURITY: Run every Monday and Thursday at 08:00 UTC
    # Catches vulnerabilities disclosed mid-week
    - cron: '0 8 * * 1,4'
  workflow_dispatch:
    # Allow manual trigger for ad-hoc scanning

permissions:
  contents: read

jobs:
  scheduled-scan:
    name: Scheduled Vulnerability Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
      issues: write  # Create issue on vulnerability detection
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: CodeQL scheduled scan
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: javascript
          queries: security-extended

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          category: 'codeql-scheduled'

      # SECURITY: Dependency vulnerability scan
      - name: Run npm audit
        id: npm-audit
        run: |
          npm audit --audit-level=moderate --json > npm-audit.json || true
          VULN_COUNT=$(jq '.metadata.vulnerabilities.total' npm-audit.json)
          echo "vuln_count=$VULN_COUNT" >> $GITHUB_OUTPUT

      # SECURITY: Create issue if vulnerabilities found
      - name: Create vulnerability issue
        if: steps.npm-audit.outputs.vuln_count > 0
        uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            const vulnCount = '${{ steps.npm-audit.outputs.vuln_count }}';
            const issueBody = `## Scheduled Security Scan Alert

            **Date**: ${new Date().toISOString()}
            **Vulnerabilities Found**: ${vulnCount}

            Automated security scan detected ${vulnCount} vulnerabilities in dependencies.

            ### Action Required
            1. Review npm audit report artifact
            2. Update vulnerable dependencies
            3. Run \`npm audit fix\` or manually update packages
            4. Re-run security scan to verify fixes

            **Workflow Run**: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
            `;

            await github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: `[Security] ${vulnCount} vulnerabilities detected in scheduled scan`,
              body: issueBody,
              labels: ['security', 'dependencies']
            });

      # SECURITY: Container scanning (if applicable)
      - name: Scan container images
        run: |
          # SECURITY: Scan production images from registry
          # Replace with your registry and image names
          for image in myapp:latest myapp:stable; do
            echo "Scanning $image..."
            podman pull ghcr.io/${{ github.repository }}/$image || true
            trivy image \
              --severity CRITICAL,HIGH \
              --format sarif \
              --output trivy-${image//[:\/]/-}.sarif \
              ghcr.io/${{ github.repository }}/$image || true
          done

      - name: Upload scheduled scan results
        if: always()
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: scheduled-scan-results
          path: |
            npm-audit.json
            trivy-*.sarif
          retention-days: 90
```
