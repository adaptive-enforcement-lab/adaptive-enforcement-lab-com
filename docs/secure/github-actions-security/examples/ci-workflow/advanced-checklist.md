---
title: Advanced Security Patterns and Checklist
description: >-
  Advanced fork PR security patterns with two-stage workflows, secret scanning prevention techniques, and comprehensive CI security checklist for production
---

!!! warning "Complete All Checklist Items"

    This checklist represents minimum security requirements for production CI workflows. Every unchecked item increases attack surface. Address all items before merging workflows to default branch.

## Trigger Security

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

- **[Action Pinning](../../action-pinning/sha-pinning.md)**: SHA pinning patterns and Dependabot configuration
- **[Token Permissions](../../token-permissions/templates.md)**: GITHUB_TOKEN permission templates for all workflow types
- **[Fork PR Security](../../workflows/triggers/index.md)**: Safe handling of fork pull requests with two-stage workflows
- **[Secret Management](../../secrets/secrets-management/index.md)**: Secret exposure prevention and OIDC patterns
- **[Security Scanning](../security-scanning/index.md)**: Comprehensive security scanning with SAST, dependency review, and SARIF upload

## Summary

Hardened CI workflows require defense in depth:

1. **Pin all actions** to SHA-256 hashes with version comments
2. **Minimize permissions** at workflow and job level
3. **Isolate fork PRs** with `pull_request` trigger and two-stage workflows
4. **Scan for secrets** before commits reach the repository
5. **Scan dependencies** for vulnerabilities on every PR
6. **Upload SARIF** findings to GitHub Security tab for visibility

Copy these templates as starting points. Adjust permissions and scanning tools based on your language stack and security requirements.
