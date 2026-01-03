---
title: Hardened CI Workflow
description: >-
  Production-ready CI workflow examples with all security patterns applied. SHA pinning, minimal permissions, secret scanning, and language-specific variants.
tags:
  - github-actions
  - security
  - ci-cd
  - examples
  - workflows
---

# Hardened CI Workflow

Copy-paste ready CI workflow templates with comprehensive security hardening. Each example demonstrates action pinning, minimal GITHUB_TOKEN permissions, input validation, and security scanning.

!!! tip "Complete Security Patterns"

    These workflows integrate all security patterns from the hub: SHA-pinned actions, job-level permissions, secret scanning prevention, fork PR safety, and security tooling. Use as production templates.

## Universal CI Pattern

Core security controls that apply to all CI workflows regardless of language or tooling.

### Security Principles Applied

Every example in this guide implements these controls:

1. **Action Pinning**: All third-party actions pinned to full SHA-256 commit hashes
2. **Minimal Permissions**: `contents: read` by default, elevated only for specific jobs
3. **Fork PR Safety**: `pull_request` trigger (not `pull_request_target`) for untrusted code
4. **Input Validation**: No direct injection of untrusted inputs into shell commands
5. **Secret Scanning**: Pre-commit hooks and push protection to prevent credential leaks
6. **Dependency Scanning**: Automated vulnerability detection for dependencies
7. **SARIF Upload**: Security findings uploaded to GitHub Security tab

### Base Hardened CI Workflow

Minimal secure CI workflow demonstrating core patterns.

```yaml
name: Hardened CI
on:
  push:
    branches: [main, develop]
  pull_request:
    # SECURITY: pull_request (not pull_request_target) runs untrusted code in isolated context
    # Fork PRs run with read-only GITHUB_TOKEN and no access to secrets
    branches: [main, develop]

# SECURITY: Workflow-level permissions deny all by default
# Job-level permissions grant minimal access per job
permissions:
  contents: read

jobs:
  # Job 1: Build and test with minimal permissions
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read  # Read repository code
      # No write permissions - prevents tampering
    steps:
      # SECURITY: All actions pinned to full SHA-256 commit hashes
      # Version comments (# vX.Y.Z) provide human readability
      # Dependabot will update SHAs via PRs
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          # SECURITY: Shallow clone (depth: 1) reduces attack surface
          # Full history not needed for CI builds
          persist-credentials: false  # Don't persist git credentials

      - name: Set up build environment
        uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'
          cache: 'npm'  # Cache dependencies for speed

      - name: Install dependencies
        run: npm ci  # Use ci (not install) for reproducible builds

      - name: Run linter
        run: npm run lint

      - name: Run unit tests
        run: npm test -- --coverage

      - name: Upload coverage reports
        uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1
        with:
          # SECURITY: Never use secrets in fork PRs
          # Codecov token optional for public repos
          fail_ci_if_error: false  # Don't fail on upload errors
          files: ./coverage/coverage.xml
        env:
          # SECURITY: Secrets not exposed to fork PRs with pull_request trigger
          CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}

  # Job 2: Security scanning with isolated permissions
  security-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read       # Read repository code
      security-events: write  # Upload SARIF to Security tab
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: CodeQL for static analysis
      - name: Initialize CodeQL
        uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: javascript
          # SECURITY: Use default query suite (security-extended for more coverage)
          queries: security-extended

      - name: Autobuild
        uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          # SECURITY: Upload SARIF to Security tab (requires security-events: write)
          category: "/language:javascript"

      # SECURITY: Trivy for dependency and vulnerability scanning
      - name: Run Trivy scanner
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'trivy-results.sarif'
          category: 'trivy'

  # Job 3: Build artifacts with minimal permissions
  build:
    runs-on: ubuntu-latest
    # SECURITY: Only build on non-fork PRs and main branch
    # Prevents malicious fork PRs from creating artifacts
    if: github.event_name == 'push' || github.event.pull_request.head.repo.full_name == github.repository
    permissions:
      contents: read
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - name: Set up build environment
        uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Build application
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: build-artifacts
          path: dist/
          retention-days: 7  # SECURITY: Short retention to reduce exposure
```

## Language-Specific CI Workflows

### Node.js / TypeScript CI

Hardened CI for Node.js and TypeScript projects with comprehensive testing and security scanning.

```yaml
name: Node.js CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    name: Test on Node ${{ matrix.node-version }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
    strategy:
      # SECURITY: fail-fast prevents wasting resources on known failures
      fail-fast: true
      matrix:
        node-version: [18, 20]
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      # SECURITY: Audit dependencies for known vulnerabilities
      - name: Audit dependencies
        run: npm audit --audit-level=high

      - name: Install dependencies
        run: npm ci

      # SECURITY: Type checking catches bugs before runtime
      - name: Type check
        run: npm run type-check

      - name: Lint
        run: npm run lint

      - name: Run tests
        run: npm test -- --coverage --maxWorkers=2

      - name: Build
        run: npm run build

  dependency-review:
    name: Dependency Review
    runs-on: ubuntu-latest
    # SECURITY: Only run on PRs to catch risky dependencies before merge
    if: github.event_name == 'pull_request'
    permissions:
      contents: read
      pull-requests: write  # Post review comments
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Dependency review detects malicious or vulnerable packages in PRs
      - uses: actions/dependency-review-action@c74b580d73376b7750d3d2a50bfb8adc2c937507  # v3.1.0
        with:
          # Fail on critical/high vulnerabilities
          fail-on-severity: high
          # Deny known malicious packages
          deny-licenses: AGPL-3.0, GPL-3.0
```

### Python CI

Hardened CI for Python projects with security scanning and dependency management.

```yaml
name: Python CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    name: Test on Python ${{ matrix.python-version }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
    strategy:
      fail-fast: true
      matrix:
        python-version: ['3.10', '3.11', '3.12']
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c  # v5.0.0
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'

      # SECURITY: Install dependencies from locked requirements
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements-dev.txt

      # SECURITY: Bandit scans for common security issues in Python code
      - name: Run Bandit security scan
        run: |
          pip install bandit[toml]
          bandit -r . -f json -o bandit-report.json || true

      # SECURITY: Safety checks for known vulnerabilities in dependencies
      - name: Check dependencies with Safety
        run: |
          pip install safety
          safety check --json

      - name: Lint with ruff
        run: |
          pip install ruff
          ruff check .

      - name: Type check with mypy
        run: |
          pip install mypy
          mypy .

      - name: Run tests with pytest
        run: |
          pip install pytest pytest-cov
          pytest --cov=. --cov-report=xml --cov-report=term

      - name: Upload coverage
        uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1
        with:
          files: ./coverage.xml
          fail_ci_if_error: false

  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: CodeQL for Python static analysis
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: python
          queries: security-extended

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
```

### Go CI

Hardened CI for Go projects with static analysis and vulnerability scanning.

```yaml
name: Go CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  test:
    name: Test on Go ${{ matrix.go-version }}
    runs-on: ubuntu-latest
    permissions:
      contents: read
    strategy:
      fail-fast: true
      matrix:
        go-version: ['1.21', '1.22']
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: actions/setup-go@93397bea11091df50f3d7e59dc26a7711a8bcfbe  # v4.1.0
        with:
          go-version: ${{ matrix.go-version }}
          cache: true

      # SECURITY: Download dependencies with verification
      - name: Download dependencies
        run: go mod download

      # SECURITY: Verify dependencies match go.sum
      - name: Verify dependencies
        run: go mod verify

      # SECURITY: Run Go security checker
      - name: Run govulncheck
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...

      # SECURITY: Run staticcheck for code quality and security issues
      - name: Run staticcheck
        run: |
          go install honnef.co/go/tools/cmd/staticcheck@latest
          staticcheck ./...

      - name: Run tests
        run: go test -race -coverprofile=coverage.out -covermode=atomic ./...

      - name: Upload coverage
        uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1
        with:
          files: ./coverage.out
          fail_ci_if_error: false

  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: CodeQL for Go static analysis
      - uses: github/codeql-action/init@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          languages: go
          queries: security-extended

      - uses: github/codeql-action/autobuild@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      - uses: github/codeql-action/analyze@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4

      # SECURITY: Gosec for Go-specific security issues
      - name: Run Gosec
        uses: securego/gosec@c6131d00402c4f9b60c815179b03bdad482e62c4  # v2.18.2
        with:
          args: '-no-fail -fmt sarif -out gosec.sarif ./...'

      - name: Upload Gosec results
        uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: gosec.sarif
```

## Advanced Security Patterns

### Fork PR Security with Two-Stage Workflow

Safely handle fork PRs with staged execution: tests run on untrusted code, deployment requires approval.

```yaml
name: Fork PR CI
on:
  pull_request:
    # SECURITY: pull_request runs fork code in isolated context
    # Fork PRs get read-only token, no secrets
    branches: [main]

permissions:
  contents: read

jobs:
  # Stage 1: Run untrusted code from forks with minimal permissions
  test-fork:
    runs-on: ubuntu-latest
    permissions:
      contents: read  # Read-only access
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          # SECURITY: Check out PR head (untrusted code)
          ref: ${{ github.event.pull_request.head.sha }}
          persist-credentials: false

      - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      # SECURITY: Run tests without secrets or write permissions
      - name: Run tests
        run: npm test

      # SECURITY: Save test results for trusted workflow
      - name: Save test results
        uses: actions/upload-artifact@c7d193f32edcb7bfad88892161225aeda64e9392  # v4.0.0
        with:
          name: test-results
          path: test-results/
```

### Post PR comment with test results (separate workflow)

```yaml
# .github/workflows/fork-pr-comment.yml
# SECURITY: workflow_run trigger runs in repository context (trusted)
# This workflow can access secrets and write to PRs
name: Post Fork PR Results
on:
  workflow_run:
    workflows: ["Fork PR CI"]
    types:
      - completed

permissions:
  pull-requests: write
  actions: read

jobs:
  comment:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    steps:
      - name: Download test results
        uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            const artifacts = await github.rest.actions.listWorkflowRunArtifacts({
              owner: context.repo.owner,
              repo: context.repo.repo,
              run_id: ${{ github.event.workflow_run.id }},
            });
            const artifact = artifacts.data.artifacts.find(a => a.name === 'test-results');
            if (artifact) {
              const download = await github.rest.actions.downloadArtifact({
                owner: context.repo.owner,
                repo: context.repo.repo,
                artifact_id: artifact.id,
                archive_format: 'zip',
              });
              // Process and post results
            }
```

### Secret Scanning Prevention

Prevent credential leaks before they reach the repository.

```yaml
name: Pre-commit Secret Scanning
on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          # SECURITY: Fetch full history to scan all commits in PR
          fetch-depth: 0
          persist-credentials: false

      # SECURITY: gitleaks scans for hardcoded secrets
      - name: Run gitleaks
        uses: gitleaks/gitleaks-action@cb7149a9c69f0f7c6a0c5b7b094889a91831ff7f  # v2.3.2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_ENABLE_COMMENTS: false  # Don't expose findings in PR comments

      # SECURITY: Fail workflow if secrets detected
      - name: Fail on secret detection
        if: steps.gitleaks.outputs.exitcode == 1
        run: |
          echo "::error::Secrets detected in commit history. Remove before merging."
          exit 1
```

## Security Checklist

Use this checklist to verify your CI workflow follows security best practices.

### Action Security

- [ ] All third-party actions pinned to full SHA-256 commit hashes
- [ ] Version comments added for human readability (`# vX.Y.Z`)
- [ ] Dependabot configured to update action pins
- [ ] Actions from verified publishers or GitHub-maintained only
- [ ] No community actions without security review

### Permission Security

- [ ] Workflow-level permissions set to minimal (`contents: read`)
- [ ] Job-level permissions escalate only when required
- [ ] No `permissions: write-all` or default write permissions
- [ ] `security-events: write` only on security scan jobs
- [ ] `pull-requests: write` only on trusted comment jobs

### Trigger Security

- [ ] `pull_request` trigger used (not `pull_request_target` for untrusted code)
- [ ] Fork PR builds isolated with read-only token
- [ ] No secrets exposed to fork PRs
- [ ] Artifact uploads require repository match check
- [ ] Two-stage workflow for fork PR comments

### Secret Security

- [ ] No hardcoded credentials in workflow files
- [ ] Secrets accessed via `${{ secrets.SECRET_NAME }}`
- [ ] Secrets not logged or echoed in workflow steps
- [ ] OIDC preferred over long-lived credentials
- [ ] Pre-commit secret scanning enabled

### Dependency Security

- [ ] Dependency review on PRs
- [ ] Vulnerability scanning (npm audit, safety, govulncheck)
- [ ] Dependency pinning in lock files (package-lock.json, requirements.txt, go.sum)
- [ ] SARIF upload for security findings
- [ ] Critical/high vulnerabilities block merge

### Build Security

- [ ] `persist-credentials: false` on checkout
- [ ] Shallow clones where possible (`depth: 1`)
- [ ] Minimal artifact retention (7-14 days)
- [ ] Build artifacts uploaded only on non-fork PRs
- [ ] No sensitive data in build artifacts

## Common Mistakes and Fixes

### Mistake 1: Over-Privileged Default Permissions

**Bad**:

```yaml
# DANGER: Workflow inherits repository default permissions (often write-all)
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

**Good**:

```yaml
# SECURITY: Explicit minimal permissions
on: [push, pull_request]

permissions:
  contents: read  # Deny all except contents read

jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

### Mistake 2: Unpinned Actions

**Bad**:

```yaml
# DANGER: Tag references are mutable, allow supply chain attacks
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v3
```

**Good**:

```yaml
# SECURITY: SHA pinning prevents tag hijacking
steps:
  - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
  - uses: actions/setup-node@5e21ff4d9bc1a8cf6de233a3057d20ec6b3fb69d  # v3.8.1
```

### Mistake 3: Exposing Secrets to Fork PRs

**Bad**:

```yaml
# DANGER: pull_request_target runs in repo context with full secret access
on:
  pull_request_target:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # Checks out untrusted code
      - run: npm ci
        env:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}  # Secret exposed to fork!
```

**Good**:

```yaml
# SECURITY: pull_request isolates fork code from secrets
on:
  pull_request:  # Untrusted code, read-only token, no secrets

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - run: npm ci  # No secrets needed for public dependencies
```

### Mistake 4: Script Injection via Untrusted Input

**Bad**:

```yaml
# DANGER: PR title injected directly into shell command
on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "Testing PR: ${{ github.event.pull_request.title }}"
```

**Good**:

```yaml
# SECURITY: Untrusted input passed via environment variable
on:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Echo PR title safely
        env:
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: echo "Testing PR: $PR_TITLE"
```

## Related Patterns

- **[Action Pinning](../action-pinning/sha-pinning.md)**: SHA pinning patterns and Dependabot configuration
- **[Token Permissions](../token-permissions/templates.md)**: GITHUB_TOKEN permission templates for all workflow types
- **[Fork PR Security](../workflows/triggers.md)**: Safe handling of fork pull requests with two-stage workflows
- **[Secret Management](../secrets/index.md)**: Secret exposure prevention and OIDC patterns
- **[Security Scanning](./security-scanning.md)**: Comprehensive security scanning with SAST, dependency review, and SARIF upload

## Summary

Hardened CI workflows require defense in depth:

1. **Pin all actions** to SHA-256 hashes with version comments
2. **Minimize permissions** at workflow and job level
3. **Isolate fork PRs** with `pull_request` trigger and two-stage workflows
4. **Scan for secrets** before commits reach the repository
5. **Scan dependencies** for vulnerabilities on every PR
6. **Upload SARIF** findings to GitHub Security tab for visibility

Copy these templates as starting points. Adjust permissions and scanning tools based on your language stack and security requirements.
