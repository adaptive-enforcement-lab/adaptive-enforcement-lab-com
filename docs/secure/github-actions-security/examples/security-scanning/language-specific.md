---
title: Language-Specific Security Scanning
description: >-
  Security scanning workflows for Node.js, Python, and Go with language-specific tools
---


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
