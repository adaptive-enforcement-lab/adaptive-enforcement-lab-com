---
title: Security Scanning Workflows
description: >-
  Comprehensive security scanning examples with SAST (CodeQL), dependency scanning, container vulnerability detection (Trivy), and SARIF upload to GitHub Security tab.
tags:
  - github-actions
  - security
  - sast
  - dependency-scanning
  - container-security
  - sarif
---

# Security Scanning Workflows

Copy-paste ready security scanning workflow templates with comprehensive coverage. Each example demonstrates SAST with CodeQL, dependency vulnerability detection, container image scanning with Trivy, and SARIF upload to GitHub Security tab for centralized visibility.

!!! tip "Complete Security Patterns"

    These workflows integrate all security scanning patterns: SHA-pinned actions, minimal GITHUB_TOKEN permissions (`security-events: write` for SARIF upload), automated scanning on every PR and push, SARIF result aggregation in GitHub Security tab, and security gates that block merges on critical findings.

## Security Scanning Principles

Every security scanning workflow in this guide implements these controls:

1. **SAST Integration**: Static analysis with CodeQL to detect code-level vulnerabilities
2. **Dependency Scanning**: Automated vulnerability detection in dependencies with severity-based gates
3. **Container Scanning**: Image vulnerability scanning with Trivy before deployment
4. **SARIF Upload**: Centralized findings in GitHub Security tab for audit and tracking
5. **Security Gates**: Block merges on critical/high severity findings
6. **Minimal Permissions**: `security-events: write` scoped to scanning jobs only
7. **Scan All Changes**: Automated scanning on every PR and main branch push

## Universal Security Scanning Workflow

Comprehensive scanning workflow covering SAST, dependencies, and containers in one pipeline.

### Multi-Scanner Security Pipeline

Complete security scanning with CodeQL, dependency review, and Trivy.

```yaml
name: Security Scanning
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  schedule:
    # SECURITY: Weekly scheduled scan catches newly-disclosed vulnerabilities
    # Run every Monday at 08:00 UTC
    - cron: '0 8 * * 1'

# SECURITY: Minimal permissions by default
permissions:
  contents: read

jobs:
  # Job 1: SAST with CodeQL
  codeql-analysis:
    name: CodeQL SAST Analysis
    runs-on: ubuntu-latest
    permissions:
      contents: read        # Read repository code
      security-events: write  # Upload SARIF to Security tab
      actions: read         # Read workflow metadata
    strategy:
      fail-fast: false
      matrix:
        # SECURITY: Scan all languages in monorepo
        language: ['javascript', 'python']
    steps:
      # SECURITY: All actions pinned to full SHA-256 commit hashes
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Initialize CodeQL for static analysis
      - name: Initialize CodeQL
        uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: ${{ matrix.language }}
          # SECURITY: security-extended includes additional checks beyond default suite
          # Use security-and-quality for maximum coverage (slower)
          queries: security-extended
          # SECURITY: Threat modeling configuration
          # Identifies sources (user input) and sinks (sensitive operations)
          config-file: ./.github/codeql/codeql-config.yml

      # SECURITY: Autobuild for compiled languages (Java, C++, C#, Go)
      # For interpreted languages (JavaScript, Python), this is a no-op
      - name: Autobuild
        uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      # SECURITY: Perform CodeQL analysis and upload results
      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          # SECURITY: Category allows multiple analyses per repository
          # Use language as category for monorepo scanning
          category: "/language:${{ matrix.language }}"
          # SECURITY: Upload SARIF to Security tab (requires security-events: write)
          upload: true
          # SECURITY: Fail workflow on high/critical findings
          # Comment out for informational-only scanning
          # fail-on: high

  # Job 2: Dependency vulnerability scanning
  dependency-scan:
    name: Dependency Vulnerability Scan
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write  # Post review comments on PRs
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Dependency review detects vulnerable and malicious packages in PRs
      # Only runs on pull_request events (not push)
      - name: Dependency Review
        if: github.event_name == 'pull_request'
        uses: actions/dependency-review-action@c74b580d73376b7750d3d2a50bfb8adc2c937507  # v3.1.0
        with:
          # SECURITY: Fail on critical/high vulnerabilities
          fail-on-severity: high
          # SECURITY: Deny licenses incompatible with your policy
          deny-licenses: AGPL-3.0, GPL-3.0
          # SECURITY: Warn on moderate/low vulnerabilities
          warn-on-severity: moderate
          # SECURITY: Comment threshold reduces PR noise
          comment-summary-in-pr: true
          # SECURITY: Allow specific packages if needed (use sparingly)
          # allow-dependencies-licenses: MIT, Apache-2.0

  # Job 3: Container image vulnerability scanning
  container-scan:
    name: Container Image Scan
    runs-on: ubuntu-latest
    # SECURITY: Only scan containers on main branch and PRs from same repo
    # Prevents fork PRs from triggering container builds
    if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
    permissions:
      contents: read
      security-events: write  # Upload SARIF to Security tab
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Build container image for scanning
      # In production, scan images from registry instead of building
      - name: Build container image
        run: |
          podman build -t myapp:${{ github.sha }} .

      # SECURITY: Scan container image with Trivy
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          # SECURITY: Scan filesystem and dependencies in container
          scan-type: 'image'
          image-ref: 'myapp:${{ github.sha }}'
          # SECURITY: SARIF format for GitHub Security tab upload
          format: 'sarif'
          output: 'trivy-results.sarif'
          # SECURITY: Fail on critical/high vulnerabilities
          severity: 'CRITICAL,HIGH'
          # SECURITY: Exit code 1 if vulnerabilities found (blocks merge)
          exit-code: '1'
          # SECURITY: Ignore unfixed vulnerabilities (optional)
          # ignore-unfixed: true

      # SECURITY: Upload Trivy results to Security tab
      - name: Upload Trivy SARIF results
        if: always()  # Upload even if scan fails
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'trivy-results.sarif'
          # SECURITY: Category allows multiple scan results
          category: 'trivy-container'

      # SECURITY: Also generate human-readable report
      - name: Generate Trivy report
        if: always()
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          scan-type: 'image'
          image-ref: 'myapp:${{ github.sha }}'
          format: 'table'
          output: 'trivy-report.txt'

      - name: Upload Trivy report
        if: always()
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: trivy-report
          path: trivy-report.txt
          retention-days: 30

  # Job 4: Secret scanning verification
  secret-scan:
    name: Secret Scanning Verification
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          # SECURITY: Fetch full history to scan all commits in PR
          fetch-depth: 0
          persist-credentials: false

      # SECURITY: Gitleaks scans for hardcoded secrets in commit history
      - name: Run gitleaks secret scan
        uses: gitleaks/gitleaks-action@cb7149a9c69f0f7c6a0c5b7b094889a91831ff7f  # v2.3.2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # SECURITY: Don't expose findings in PR comments (use Security tab)
          GITLEAKS_ENABLE_COMMENTS: false
          # SECURITY: Fail on secret detection
          GITLEAKS_ENABLE_UPLOAD_ARTIFACT: true
```

## Language-Specific Security Scanning

### Node.js / TypeScript Security Scanning

Comprehensive security scanning for Node.js projects with npm audit and ESLint security rules.

```yaml
name: Node.js Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 8 * * 1'  # Weekly Monday 08:00 UTC

permissions:
  contents: read

jobs:
  security-scan:
    name: Node.js Security Analysis
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
      pull-requests: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
          cache: 'npm'

      # SECURITY: npm audit checks for known vulnerabilities in dependencies
      - name: npm audit
        run: |
          # SECURITY: Audit production and development dependencies
          npm audit --audit-level=high --json > npm-audit.json || true
          # SECURITY: Print human-readable report
          npm audit --audit-level=high

      # SECURITY: Upload audit results as artifact
      - name: Upload npm audit results
        if: always()
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: npm-audit-report
          path: npm-audit.json
          retention-days: 30

      - name: Install dependencies
        run: npm ci

      # SECURITY: ESLint with security plugin detects common vulnerabilities
      - name: Run ESLint security scan
        run: |
          npm install --save-dev eslint-plugin-security
          npx eslint . --ext .js,.ts,.tsx --format json --output-file eslint-security.json || true
          npx eslint . --ext .js,.ts,.tsx

      # SECURITY: CodeQL for JavaScript/TypeScript SAST
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: javascript
          queries: security-extended

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          category: "/language:javascript"

      # SECURITY: Dependency review on PRs
      - name: Dependency Review
        if: github.event_name == 'pull_request'
        uses: actions/dependency-review-action@c74b580d73376b7750d3d2a50bfb8adc2c937507  # v3.1.0
        with:
          fail-on-severity: high
          deny-licenses: AGPL-3.0, GPL-3.0

      # SECURITY: Retire.js scans for vulnerable JavaScript libraries
      - name: Run Retire.js
        run: |
          npm install -g retire
          retire --js --path . --outputformat json --outputpath retire-report.json || true
          retire --js --path .

      - name: Upload Retire.js results
        if: always()
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: retire-report
          path: retire-report.json
          retention-days: 30
```

### Python Security Scanning

Hardened security scanning for Python projects with Bandit, Safety, and CodeQL.

```yaml
name: Python Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 8 * * 1'

permissions:
  contents: read

jobs:
  security-scan:
    name: Python Security Analysis
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.11'
          cache: 'pip'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt -r requirements-dev.txt

      # SECURITY: Bandit scans Python code for common security issues
      - name: Run Bandit SAST
        run: |
          pip install bandit[toml]
          # SECURITY: Generate SARIF format for Security tab upload
          bandit -r . -f sarif -o bandit-results.sarif || true
          # SECURITY: Also generate human-readable report
          bandit -r . -f json -o bandit-report.json || true
          bandit -r .

      # SECURITY: Upload Bandit SARIF to Security tab
      - name: Upload Bandit SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: bandit-results.sarif
          category: 'bandit'

      # SECURITY: Safety checks dependencies for known vulnerabilities
      - name: Run Safety dependency scan
        run: |
          pip install safety
          # SECURITY: Check against vulnerability database
          safety check --json --output safety-report.json || true
          safety check

      - name: Upload Safety results
        if: always()
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: safety-report
          path: safety-report.json
          retention-days: 30

      # SECURITY: pip-audit checks installed packages for vulnerabilities
      - name: Run pip-audit
        run: |
          pip install pip-audit
          pip-audit --format json --output pip-audit.json || true
          pip-audit

      # SECURITY: CodeQL for Python SAST
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: python
          queries: security-extended
          # SECURITY: Setup Python dependencies for CodeQL analysis
          setup-python-dependencies: true

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          category: "/language:python"
```

### Go Security Scanning

Security scanning for Go projects with gosec, govulncheck, and CodeQL.

```yaml
name: Go Security Scan
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 8 * * 1'

permissions:
  contents: read

jobs:
  security-scan:
    name: Go Security Analysis
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-go@93397bea11091df50f3d7e59dc26a7711a8bcfbe  # v4.1.0
        with:
          go-version: '1.22'
          cache: true

      # SECURITY: Download and verify dependencies
      - name: Download dependencies
        run: go mod download

      # SECURITY: Verify dependencies match go.sum
      - name: Verify dependencies
        run: go mod verify

      # SECURITY: govulncheck scans for known vulnerabilities in dependencies
      - name: Run govulncheck
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck -json ./... > govulncheck-report.json || true
          govulncheck ./...

      - name: Upload govulncheck results
        if: always()
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: govulncheck-report
          path: govulncheck-report.json
          retention-days: 30

      # SECURITY: gosec scans Go code for security issues
      - name: Run gosec SAST
        uses: securego/gosec@c6131d00402c4f9b60c815179b03bdad482e62c4  # v2.18.2
        with:
          # SECURITY: Generate SARIF format for Security tab
          args: '-no-fail -fmt sarif -out gosec-results.sarif ./...'

      # SECURITY: Upload gosec SARIF to Security tab
      - name: Upload gosec SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: gosec-results.sarif
          category: 'gosec'

      # SECURITY: CodeQL for Go SAST
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: go
          queries: security-extended

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          category: "/language:go"

      # SECURITY: staticcheck for additional Go code quality and security checks
      - name: Run staticcheck
        run: |
          go install honnef.co/go/tools/cmd/staticcheck@latest
          staticcheck ./...
```

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

## CodeQL Configuration

### Custom CodeQL Configuration

Advanced CodeQL configuration for fine-tuned SAST analysis.

```yaml
# .github/codeql/codeql-config.yml
# SECURITY: Custom CodeQL configuration for enhanced analysis

name: "Custom CodeQL Config"

# SECURITY: Disable default query suites, use explicit queries
disable-default-queries: false

# SECURITY: Additional query packs for comprehensive scanning
queries:
  - name: "Security Extended Queries"
    uses: security-extended
  - name: "Security and Quality Queries"
    uses: security-and-quality

# SECURITY: Query filters to reduce false positives
query-filters:
  # Exclude specific queries that generate noise
  - exclude:
      id: js/unused-local-variable

# SECURITY: Path filters to exclude test files and vendor code
paths-ignore:
  - 'node_modules/**'
  - 'vendor/**'
  - 'test/**'
  - 'tests/**'
  - '**/*.test.js'
  - '**/*.spec.ts'

# SECURITY: Explicitly include critical paths
paths:
  - 'src/**'
  - 'lib/**'
  - 'app/**'

# SECURITY: External repositories for reusable CodeQL queries
external-repository-token: ${{ secrets.GITHUB_TOKEN }}
```

### Language-Specific CodeQL Workflow

```yaml
name: CodeQL SAST
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 8 * * 1'

permissions:
  contents: read

jobs:
  codeql:
    name: CodeQL Analysis (${{ matrix.language }})
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
      actions: read
    strategy:
      fail-fast: false
      matrix:
        # SECURITY: Add all languages in your repository
        language: ['javascript', 'python', 'go']
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: ${{ matrix.language }}
          queries: security-and-quality
          config-file: ./.github/codeql/codeql-config.yml

      # SECURITY: Language-specific setup
      - name: Setup Python
        if: matrix.language == 'python'
        uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: '3.11'

      - name: Setup Node.js
        if: matrix.language == 'javascript'
        uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'

      - name: Setup Go
        if: matrix.language == 'go'
        uses: actions/setup-go@93397bea11091df50f3d7e59dc26a7711a8bcfbe  # v4.1.0
        with:
          go-version: '1.22'

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          category: "/language:${{ matrix.language }}"
          # SECURITY: Upload results even if analysis finds issues
          upload: true
```

## Security Checklist

Use this checklist to verify your security scanning workflow follows best practices.

### SAST (Static Analysis) Security

- [ ] CodeQL configured with `security-extended` or `security-and-quality` queries
- [ ] CodeQL scans all languages in repository (JavaScript, Python, Go, etc.)
- [ ] Custom CodeQL configuration excludes test files and vendor code
- [ ] Language-specific SAST tools enabled (ESLint, Bandit, gosec)
- [ ] SAST runs on every PR and push to main branch
- [ ] SARIF results uploaded to GitHub Security tab with unique categories

### Dependency Scanning Security

- [ ] Dependency review action enabled on pull requests
- [ ] `fail-on-severity: high` blocks merge on critical/high vulnerabilities
- [ ] License scanning configured with deny-list (AGPL, GPL if needed)
- [ ] Language-specific dependency scanning (npm audit, Safety, govulncheck)
- [ ] Scheduled scans detect newly-disclosed vulnerabilities in existing dependencies
- [ ] Dependabot configured for automated dependency updates

### Container Scanning Security

- [ ] Dockerfile scanned for misconfigurations with Trivy config scanner
- [ ] Container images scanned for vulnerabilities before deployment
- [ ] `exit-code: 1` configured to block vulnerable image deployment
- [ ] SBOM generated for all container images
- [ ] SBOM scanned with Grype or Trivy
- [ ] Container scanning runs only on non-fork PRs (repository match check)

### SARIF Upload Security

- [ ] All security tools upload SARIF to GitHub Security tab
- [ ] Unique category assigned per tool (codeql, trivy, gosec, etc.)
- [ ] `security-events: write` permission scoped to scanning jobs only
- [ ] `if: always()` on SARIF upload steps (upload even on scan failure)
- [ ] SARIF uploads use pinned `github/codeql-action/upload-sarif` action

### Permission Security

- [ ] Workflow-level permissions set to `contents: read`
- [ ] Job-level `security-events: write` only on scanning jobs
- [ ] No `permissions: write-all` in security workflows
- [ ] `pull-requests: write` only if posting review comments
- [ ] `id-token: write` only for OIDC authentication (container signing)

### Scheduled Scanning Security

- [ ] Weekly scheduled scans configured (`cron: '0 8 * * 1'`)
- [ ] Scheduled scans create GitHub issues on vulnerability detection
- [ ] Manual workflow dispatch trigger enabled for ad-hoc scanning
- [ ] Scan results uploaded as artifacts with 90-day retention
- [ ] Alert routing configured (Slack, email, PagerDuty)

### Secret Scanning Security

- [ ] Gitleaks or similar tool scans commit history for secrets
- [ ] Full history fetched (`fetch-depth: 0`) for comprehensive scanning
- [ ] Secret scanning runs on every PR
- [ ] GitHub secret scanning and push protection enabled
- [ ] Custom secret patterns defined for internal credential formats

## Common Mistakes and Fixes

### Mistake 1: Missing security-events Permission

**Bad**:

```yaml
# DANGER: CodeQL analysis fails without security-events permission
jobs:
  codeql:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: github/codeql-action/analyze@v2
```

**Good**:

```yaml
# SECURITY: Grant security-events write permission for SARIF upload
jobs:
  codeql:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write  # Required for SARIF upload
    steps:
      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
```

### Mistake 2: Not Uploading SARIF Results

**Bad**:

```yaml
# DANGER: Trivy results not visible in Security tab
- name: Run Trivy scan
  run: trivy image myapp:latest --severity CRITICAL,HIGH
```

**Good**:

```yaml
# SECURITY: Upload SARIF to Security tab for centralized visibility
- name: Run Trivy scan
  uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
  with:
    scan-type: 'image'
    image-ref: 'myapp:latest'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy SARIF
  if: always()
  uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
  with:
    sarif_file: 'trivy-results.sarif'
    category: 'trivy'
```

### Mistake 3: Scanning on Fork PRs Without Repository Check

**Bad**:

```yaml
# DANGER: Fork PRs can trigger container builds with malicious Dockerfiles
on: [pull_request]

jobs:
  container-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: podman build -t myapp:latest .
      - run: trivy image myapp:latest
```

**Good**:

```yaml
# SECURITY: Only scan containers from same repository (not forks)
on: [pull_request]

jobs:
  container-scan:
    runs-on: ubuntu-latest
    # SECURITY: Block fork PRs from building containers
    if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - run: podman build -t myapp:latest .
      - uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
```

### Mistake 4: No Severity-Based Failure

**Bad**:

```yaml
# DANGER: Vulnerabilities detected but workflow passes
- name: Run Trivy scan
  uses: aquasecurity/trivy-action@v0.16.1
  with:
    scan-type: 'image'
    image-ref: 'myapp:latest'
    format: 'sarif'
```

**Good**:

```yaml
# SECURITY: Fail workflow on critical/high vulnerabilities
- name: Run Trivy scan
  uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
  with:
    scan-type: 'image'
    image-ref: 'myapp:latest'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'  # Fail on vulnerabilities
```

### Mistake 5: Missing SARIF Category

**Bad**:

```yaml
# DANGER: Multiple scans overwrite each other without unique categories
- uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'

- uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'gosec-results.sarif'
```

**Good**:

```yaml
# SECURITY: Unique category per tool prevents result overwrites
- uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
  with:
    sarif_file: 'trivy-results.sarif'
    category: 'trivy'

- uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
  with:
    sarif_file: 'gosec-results.sarif'
    category: 'gosec'
```

### Mistake 6: No Scheduled Scanning

**Bad**:

```yaml
# DANGER: Only scans on code changes, misses newly-disclosed vulnerabilities
on:
  push:
    branches: [main]
  pull_request:
```

**Good**:

```yaml
# SECURITY: Scheduled scans catch new vulnerabilities in existing code
on:
  push:
    branches: [main]
  pull_request:
  schedule:
    - cron: '0 8 * * 1'  # Weekly Monday 08:00 UTC
```

## Related Patterns

- **[CI Workflow](./ci-workflow.md)**: Hardened CI workflow with integrated security scanning
- **[Release Workflow](./release-workflow.md)**: Signed releases with SLSA provenance and attestations
- **[Token Permissions](../token-permissions/templates.md)**: GITHUB_TOKEN permission templates for security scanning jobs
- **[Action Pinning](../action-pinning/sha-pinning.md)**: SHA pinning patterns for security scanning actions
- **[Secret Management](../secrets/scanning.md)**: GitHub secret scanning and push protection configuration
- **[Third-Party Actions](../third-party-actions/common-actions.md)**: Security review of common scanning actions (CodeQL, Trivy, Dependabot)

## Summary

Comprehensive security scanning requires multiple detection layers:

1. **SAST with CodeQL**: Detect code-level vulnerabilities (injection, XSS, path traversal)
2. **Dependency scanning**: Catch known vulnerabilities in third-party packages
3. **Container scanning**: Find OS and application vulnerabilities in images
4. **SARIF upload**: Centralize findings in GitHub Security tab for audit trail
5. **Security gates**: Block merges on critical/high severity findings
6. **Scheduled scanning**: Detect newly-disclosed vulnerabilities in existing code
7. **Multi-tool approach**: Layer scanning tools for comprehensive coverage

Security scanning is not optional. It is table stakes for production deployments. Copy these templates and customize based on your language stack, deployment model, and risk tolerance.
