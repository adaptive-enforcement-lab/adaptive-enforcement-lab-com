---
title: Advanced Security Patterns
description: >-
  Third-party actions evaluation, runner security, and advanced patterns
---

    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
      - run: npm test
      # Secrets not accessible - safe from exfiltration

# Save artifacts for later comment workflow

  save-pr-number:
    runs-on: ubuntu-latest
    steps:
      - run: echo "${{ github.event.number }}" > pr-number.txt
      - uses: actions/upload-artifact@26f96dfa697d77e81fd5907df203aa23a56210a8  # v4.3.0
        with:
          name: pr-number
          path: pr-number.txt

```

```yaml
# .github/workflows/comment.yml (separate workflow)
name: PR Comment
on:
  workflow_run:  # Triggered after ci.yml completes
    workflows: ["CI"]
    types: [completed]

permissions:
  pull-requests: write  # Write access in trusted context

jobs:
  comment:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.conclusion == 'success'
    steps:
      - uses: actions/download-artifact@6b208ae046db98c579e8a3aa621ab581ff575935  # v4.1.1
        with:
          name: pr-number
          github-token: ${{ secrets.GITHUB_TOKEN }}
          run-id: ${{ github.event.workflow_run.id }}

      - name: Post comment
        run: |
          PR_NUMBER=$(cat pr-number.txt)
          gh pr comment "$PR_NUMBER" --body "Tests passed ✅"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

[**See trigger patterns →**](workflows/triggers.md)

### Input Validation

```yaml
steps:
  # ❌ DANGEROUS: Direct injection
  # - run: echo "PR title is ${{ github.event.pull_request.title }}"

  # ✅ SAFE: Environment variable injection
  - name: Validate and use input
    env:
      PR_TITLE: ${{ github.event.pull_request.title }}
    run: |
      # Validate format
      if [[ ! "$PR_TITLE" =~ ^[a-zA-Z0-9\ \:\-\[\]]+$ ]]; then
        echo "Invalid PR title format"
        exit 1
      fi
      echo "PR title is: $PR_TITLE"
```

## Environment Protection

Gate production deployments with approval workflows.

### Protection Rules

```yaml
# Workflow configuration
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production  # References environment with protection rules
      url: https://example.com
    steps:
      - run: ./deploy.sh
```

**Configure protection in Settings → Environments → production:**

- ✅ Required reviewers: 2 approvers from security-team
- ✅ Wait timer: 5 minutes (sanity check window)
- ✅ Deployment branches: `main` and `release/*` only
- ✅ Environment secrets: Production credentials scoped to this environment

[**See environment patterns →**](workflows/environments.md)

## Reusable Workflows

Secure inputs and pin workflow references.

### Secure Reusable Workflow Pattern

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
        # ✅ GOOD: Choice type prevents injection
        # Note: GitHub doesn't support 'enum' yet, validate at runtime
      version:
        required: true
        type: string
    secrets:
      # ✅ GOOD: Explicit secret declaration
      DEPLOY_TOKEN:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      # ✅ GOOD: Validate caller repository
      - name: Validate caller
        run: |
          ALLOWED_REPOS=("myorg/app1" "myorg/app2")
          CALLER="${{ github.repository }}"
          if [[ ! " ${ALLOWED_REPOS[@]} " =~ " ${CALLER} " ]]; then
            echo "Unauthorized caller: $CALLER"
            exit 1
          fi

      # ✅ GOOD: Validate input format
      - name: Validate inputs
        env:
          ENV_INPUT: ${{ inputs.environment }}
          VERSION_INPUT: ${{ inputs.version }}
        run: |
          if [[ ! "$ENV_INPUT" =~ ^(dev|staging|prod)$ ]]; then
            echo "Invalid environment"
            exit 1
          fi
          if [[ ! "$VERSION_INPUT" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "Invalid version format"
            exit 1
          fi

      - run: ./deploy.sh "${{ inputs.environment }}" "${{ inputs.version }}"
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
```

### Calling Reusable Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  workflow_dispatch:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, staging, prod]

jobs:
  deploy:
    # ✅ GOOD: Pin reusable workflow to SHA
    uses: myorg/workflows/.github/workflows/reusable-deploy.yml@a1b2c3d4e5f6
    with:
      environment: ${{ inputs.environment }}
      version: v1.2.3
    secrets:
      DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
```

[**See reusable workflow patterns →**](workflows/reusable.md)

## Complete Examples

Production-ready workflow templates:

| Example | Coverage | Link |
| ------- | -------- | ---- |
| **CI Workflow** | SHA pinning, minimal permissions, security scanning, fork PR safety | [View →](examples/ci-workflow.md) |
| **Release Workflow** | SLSA provenance, signed releases, attestations, package publishing | [View →](examples/release-workflow.md) |
| **Deployment Workflow** | OIDC authentication, environment protection, canary rollout, rollback | [View →](examples/deployment-workflow.md) |
| **Security Scanning** | CodeQL, Trivy, dependency scanning, SARIF upload, scheduled scans | [View →](examples/security-scanning.md) |

## Security Audit Scripts

### Audit for Unpinned Actions

```bash
#!/bin/bash
# audit-actions.sh - Find unpinned actions in workflows

echo "Scanning for unpinned GitHub Actions..."

find .github/workflows -name "*.yml" -o -name "*.yaml" | while read -r file; do
  # Find uses: lines with @tag instead of @SHA
  unpinned=$(grep -E "uses:.*@v[0-9]" "$file" || true)
  if [[ -n "$unpinned" ]]; then
    echo "❌ $file"
    echo "$unpinned"
    echo
  fi
done

echo "Scan complete. Pin actions to SHA for security."
```

[**See automation guide →**](action-pinning/automation.md)

### Audit for Over-Privileged Workflows

```bash
#!/bin/bash
# audit-permissions.sh - Find workflows without explicit permissions

echo "Scanning for workflows with default permissions..."

find .github/workflows -name "*.yml" -o -name "*.yaml" | while read -r file; do
  if ! grep -q "^permissions:" "$file"; then
    echo "⚠️  $file - Missing permissions block (defaults to write-all)"
  fi
done

echo "Add explicit permissions blocks to all workflows."
```

### Audit for Dangerous Triggers

```bash
#!/bin/bash
# audit-triggers.sh - Find pull_request_target usage

echo "Scanning for pull_request_target triggers..."

find .github/workflows -name "*.yml" -o -name "*.yaml" | while read -r file; do
  if grep -q "pull_request_target:" "$file"; then
    echo "⚠️  $file - Uses pull_request_target (review for injection risks)"
  fi
done

echo "Ensure pull_request_target workflows validate inputs and don't execute untrusted code."
```

## Priority Hardening Roadmap

Implement security controls in this order for maximum impact:

### Phase 1: Supply Chain (Week 1)

- [ ] Pin all actions to full SHA-256 hashes
- [ ] Add version comments to all pinned actions
- [ ] Enable Dependabot for automated action updates
- [ ] Run audit script to verify no unpinned actions

**Impact**: Prevents supply chain attacks
[**See action pinning →**](action-pinning/index.md)

### Phase 2: Token Permissions (Week 1-2)

- [ ] Add explicit `permissions` blocks to all workflows
- [ ] Set workflow-level to minimal (usually `contents: read`)
- [ ] Escalate job-level permissions only where needed
- [ ] Run audit script to verify no default permissions

**Impact**: Limits blast radius of successful attacks
[**See token permissions →**](token-permissions/index.md)

### Phase 3: Secret Management (Week 2-3)

- [ ] Migrate cloud authentication to OIDC federation
- [ ] Enable secret scanning with push protection
- [ ] Implement secret rotation schedule for remaining secrets
- [ ] Configure environment secrets for production deployments

**Impact**: Eliminates long-lived credentials
[**See secret management →**](secrets/index.md)

### Phase 4: Workflow Triggers (Week 3-4)

- [ ] Review all workflows using `pull_request_target`
- [ ] Implement two-stage pattern for fork PR comments
- [ ] Add input validation for all `github.event.*` usage
- [ ] Run audit script to verify trigger safety

**Impact**: Prevents fork-based injection attacks
[**See workflow patterns →**](workflows/triggers.md)

### Phase 5: Runner Security (Week 4+)

- [ ] Migrate self-hosted runners to ephemeral patterns
- [ ] Implement deny-by-default firewall rules
- [ ] Configure runner groups with repository restrictions
- [ ] Block cloud metadata endpoints

**Impact**: Prevents persistent access and lateral movement
[**See runner security →**](runners/index.md)

## Additional Resources

- **[GitHub Actions Security Hub](index.md)**: Full documentation and patterns
- **[GitHub Security Hardening Guide](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)**: Official documentation
- **[OpenSSF Scorecard](https://github.com/ossf/scorecard)**: Automated security assessment
- **[StepSecurity Harden-Runner](https://github.com/step-security/harden-runner)**: Runtime security monitoring

---

!!! success "Quick Wins"

    **Implement these three patterns today** for immediate security improvement:

    1. **SHA pin all actions** with version comments
    2. **Add `permissions: contents: read`** to workflow-level in all workflows
    3. **Enable secret scanning push protection** in repository settings

    These changes require minimal workflow modifications and dramatically reduce attack surface.
