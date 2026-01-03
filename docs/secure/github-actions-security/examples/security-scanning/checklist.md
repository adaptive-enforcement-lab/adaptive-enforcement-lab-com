---
title: Security Scanning Checklist
description: >-
  Comprehensive security scanning checklist with SAST, dependency scanning, container scanning, and common workflow mistakes
---

## Security Checklist

!!! warning "Security Scanning is Non-Negotiable"

    Every unchecked item represents a detection gap. Complete all checklist items before deploying to production. Security scanning is not optional—it is baseline hygiene for modern software delivery.

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

- **[CI Workflow](../ci-workflow/index.md)**: Hardened CI workflow with integrated security scanning
- **[Release Workflow](../release-workflow/index.md)**: Signed releases with SLSA provenance and attestations
- **[Token Permissions](../../token-permissions/templates.md)**: GITHUB_TOKEN permission templates for security scanning jobs
- **[Action Pinning](../../action-pinning/sha-pinning.md)**: SHA pinning patterns for security scanning actions
- **[Secret Management](../../secrets/scanning/index.md)**: GitHub secret scanning and push protection configuration
- **[Third-Party Actions](../../third-party-actions/common-actions.md)**: Security review of common scanning actions (CodeQL, Trivy, Dependabot)

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
