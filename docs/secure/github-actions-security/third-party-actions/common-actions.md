---
title: Common Actions Security Review
description: >-
  Pre-reviewed security assessment of frequently-used GitHub Actions with permission requirements, safe usage patterns, and known issues.
tags:
  - github-actions
  - security
  - third-party-actions
  - common-actions
---

# Common Actions Security Review

Pre-vetted analysis of the most commonly used GitHub Actions. Know what you're adopting before you add it to your workflows.

!!! tip "How to Use This Guide"

    This page provides ready-to-reference security assessments for popular actions. Verify the assessment matches your version and apply recommended pinning patterns.

## Core GitHub Actions (Tier 1)

### actions/checkout@v4.1.1

**Risk**: Low | **Permissions**: `contents: read`

```yaml
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
  with:
    persist-credentials: false  # CRITICAL: Prevent token exposure
    fetch-depth: 1              # Shallow clone for CI
```

**Known Issues**: Persists credentials in `.git/config` by default, making GITHUB_TOKEN accessible to all steps.

**Best Practices**: Always set `persist-credentials: false` unless git authentication needed. Use `fetch-depth: 0` only for full-history scanning (secrets detection, SAST).

---

### actions/setup-node@v4.0.2

**Risk**: Low | **Permissions**: `contents: read`

```yaml
- uses: actions/setup-node@60edb5dd545a775178f52524783378180af0d1f8  # v4.0.2
  with:
    node-version: '20'
    cache: 'npm'
```

**Known Issues**: None.

**Best Practices**: Pin `node-version`, enable built-in caching.

---

### actions/cache@v4.0.2

**Risk**: Low | **Permissions**: `contents: read`

```yaml
- uses: actions/cache@0c45773b623bea8c8e75f6c82b208c3cf94ea4f9  # v4.0.2
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
```

**Known Issues**: Cache poisoning possible with predictable keys. Caches accessible across workflows with matching keys.

**Best Practices**: Include content hash in key. Never cache secrets or `.env` files.

---

### actions/upload-artifact@v4.3.1 / actions/download-artifact@v4.1.4

**Risk**: Low | **Permissions**: `contents: read`

```yaml
- uses: actions/upload-artifact@5d5d22a31266ced268874388b861e4b58bb5c2f3  # v4.3.1
  with:
    name: dist
    path: dist/
    retention-days: 7
```

**Known Issues**: Artifacts accessible to anyone with repo read access. Default 90-day retention increases costs.

**Best Practices**: Set short `retention-days`. Never upload secrets, credentials, or `.env` files.

---

## Cloud Provider Actions (Tier 2)

### aws-actions/configure-aws-credentials@v4.0.2

**Risk**: Medium | **Permissions**: `id-token: write`, `contents: read`

```yaml
- uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502  # v4.0.2
  with:
    role-to-assume: arn:aws:iam::123456789012:role/github-actions
    role-session-name: github-actions-session
    aws-region: us-east-1
    # NEVER use aws-access-key-id/aws-secret-access-key
```

**Known Issues**: Supports insecure static credentials. IAM roles often overly broad.

**Best Practices**: **ALWAYS use OIDC** (`role-to-assume`), never static keys. Scope IAM trust policy to specific repo/branch/environment.

---

### google-github-actions/auth@v2.1.2

**Risk**: Medium | **Permissions**: `id-token: write`, `contents: read`

```yaml
- uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
  with:
    workload_identity_provider: projects/123/locations/global/workloadIdentityPools/github/providers/github
    service_account: github-actions@project.iam.gserviceaccount.com
```

**Known Issues**: Service accounts often over-privileged.

**Best Practices**: Use Workload Identity Federation, never service account keys. Scope pool to specific repos/branches.

---

## Build and Deploy Actions

### docker/build-push-action@v5.1.0

**Maintainer**: Docker (Verified) | **Risk**: Medium | **Permissions**: `contents: read`, `packages: write`

```yaml
- uses: docker/build-push-action@4a13e500e55cf31b7a5d59a38ab2040ab0f42f56  # v5.1.0
  with:
    context: .
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
    provenance: true  # SLSA provenance
    sbom: true        # Software Bill of Materials
```

**Known Issues**: Registry credentials stored as secrets. Base image signatures not validated.

**Best Practices**: Enable `provenance` and `sbom`. Tag with commit SHA. Pin base images in Containerfile by SHA. Scan with Trivy before push.

**Alternatives**: podman CLI, kaniko for daemonless builds.

---

### actions/deploy-pages@v4.0.5

**Risk**: Low | **Permissions**: `pages: write`, `id-token: write`, `contents: read`

```yaml
- uses: actions/deploy-pages@d6db90164ac5ed86f2b6aed7e0febac5b3c0c03e  # v4.0.5
```

**Known Issues**: None.

**Best Practices**: Deploy only from protected branches. Use environment protection rules.

---

## Security and Quality Actions

### github/codeql-action@v3.24.6

**Risk**: Low | **Permissions**: `security-events: write`, `contents: read`, `actions: read`

```yaml
- uses: github/codeql-action/init@47b3d888fe66b639e431e6d4e5d5528d98e54c1f  # v3.24.6
  with:
    languages: javascript, python
    queries: security-and-quality

- uses: github/codeql-action/autobuild@47b3d888fe66b639e431e6d4e5d5528d98e54c1f  # v3.24.6

- uses: github/codeql-action/analyze@47b3d888fe66b639e431e6d4e5d5528d98e54c1f  # v3.24.6
```

**Known Issues**: None.

**Best Practices**: Run on schedule (weekly) and pull requests. Use `security-and-quality` queries.

**Alternatives**: Semgrep, Snyk Code, SonarCloud.

---

### aquasecurity/trivy-action@v0.17.0

**Maintainer**: Aqua Security (Verified) | **Risk**: Medium | **Permissions**: `security-events: write`, `contents: read`

```yaml
- uses: aquasecurity/trivy-action@062f2592684a31eb3aa050cc61e7ca1451cecd3d  # v0.17.0
  with:
    image-ref: ghcr.io/${{ github.repository }}:${{ github.sha }}
    format: sarif
    output: trivy-results.sarif
    severity: CRITICAL,HIGH

- uses: github/codeql-action/upload-sarif@47b3d888fe66b639e431e6d4e5d5528d98e54c1f  # v3.24.6
  with:
    sarif_file: trivy-results.sarif
```

**Known Issues**: None.

**Best Practices**: Scan every container build. Filter by severity. Upload SARIF to Security tab. Fail on CRITICAL findings.

**Alternatives**: Snyk Container, Grype, Clair.

---

### codecov/codecov-action@v4.0.1

**Maintainer**: Codecov (Community) | **Risk**: High (Tier 3) | **Permissions**: `contents: read`

```yaml
- uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044  # v4.0.1
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
    files: ./coverage/coverage.xml
    fail_ci_if_error: false
```

**Known Issues**: **Supply Chain Compromise (2021)**: Bash uploader compromised, exposed CI secrets. Incident resolved but demonstrates third-party risk.

**Best Practices**: SHA pin strictly. Use repo-scoped token. Set `fail_ci_if_error: false`. Review source quarterly. **Consider forking to org control.**

**Alternatives**: Coveralls, built-in CI coverage tracking.

---

### dependabot (Built-in)

**Risk**: Low

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    groups:
      github-actions:
        patterns: ["*"]
```

**Known Issues**: None.

**Best Practices**: Enable for all ecosystems. Group updates. Configure auto-merge for Tier 1 actions with passing CI.

**Alternatives**: Renovate Bot.

---

## Summary Table

| Action | Tier | Risk | Key Concern | Mitigation |
| ------ | ---- | ---- | ----------- | ---------- |
| **actions/checkout** | 1 | Low | Credential persistence | `persist-credentials: false` |
| **actions/setup-node** | 1 | Low | None | Standard usage safe |
| **actions/cache** | 1 | Low | Cache poisoning | Content hash in key |
| **actions/upload-artifact** | 1 | Low | Artifact exposure | Never upload secrets |
| **aws-actions/configure-aws-credentials** | 2 | Medium | Static credentials | Always use OIDC |
| **google-github-actions/auth** | 2 | Medium | Service account scope | Minimal IAM roles |
| **docker/build-push-action** | 2 | Medium | Registry auth | OIDC + provenance |
| **actions/deploy-pages** | 1 | Low | None | Environment protection |
| **github/codeql-action** | 1 | Low | None | Standard usage safe |
| **aquasecurity/trivy-action** | 2 | Medium | None | SARIF upload |
| **codecov/codecov-action** | 3 | High | 2021 supply chain breach | Fork + quarterly review |
| **dependabot** | 1 | Low | None | Enable for all ecosystems |

## Quick Reference: Safe Adoption Checklist

- [ ] Verify action version matches this assessment
- [ ] SHA pin to commit hash, not tag
- [ ] Review permission requirements, grant minimum necessary
- [ ] Apply recommended usage pattern
- [ ] Enable Dependabot for updates
- [ ] Tier 2/3: Review source code before first use
- [ ] Tier 3: Consider forking to org control

## Assessment Criteria

Each action evaluated against:

- **Trust Tier**: From [Risk Assessment Framework](index.md)
- **Permission Requirements**: Minimal GITHUB_TOKEN permissions
- **Secret Access**: Required credentials
- **Known Issues**: Security advisories, CVEs, incidents
- **Safe Usage Pattern**: Copy-paste ready secure example
- **Alternatives**: Comparable or native solutions

## Next Steps

- **[Evaluation Criteria](evaluation.md)**: Assess actions not covered here
- **[Allowlisting Guide](allowlisting.md)**: Restrict org to approved actions
- **[Risk Assessment Framework](index.md)**: Understand trust tiers

---

!!! warning "Assessment Validity"

    Current as of January 2026. Actions evolve, vulnerabilities emerge, maintainers change. Re-evaluate quarterly and monitor security advisories.
