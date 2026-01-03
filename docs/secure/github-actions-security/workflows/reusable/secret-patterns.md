---
title: Secret Inheritance Patterns
description: >-
  Safe secret passing patterns for reusable workflows with caller validation
---

    with:
      environment: production
    secrets: inherit  # DANGEROUS: Passes all secrets

```

**Risk**: Reusable workflow has access to ALL repository and organization secrets, including unrelated credentials.

**Attack Vector**: If reusable workflow is compromised, attacker can exfiltrate all secrets.

### Safe: Explicit Secret Passing

```yaml
# Reusable workflow
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, staging, production]
    secrets:
      wif_provider:
        required: true
        description: 'GCP Workload Identity Federation provider'
      wif_service_account:
        required: true
        description: 'GCP service account for deployment'

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.wif_provider }}
          service_account: ${{ secrets.wif_service_account }}

      - run: ./scripts/deploy.sh ${{ inputs.environment }}
```

```yaml
# Caller workflow
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml@b4ffde65f46336ab88eb53be808477a3936bae11
    with:
      environment: production
    secrets:
      wif_provider: ${{ secrets.WIF_PROVIDER }}
      wif_service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
      # Only deployment secrets passed, not all secrets
```

**Key Improvements**:

1. Reusable workflow declares required secrets
2. Caller explicitly passes only needed secrets
3. Blast radius limited to deployment credentials
4. Clear documentation of secret requirements

### Secret Inheritance Comparison

| Method | Risk Level | Use Case |
| ------ | ---------- | -------- |
| `secrets: inherit` | High | Avoid. Only for trusted internal workflows with full secret access requirement |
| Explicit secrets | Low | Always prefer. Pass only required secrets |
| No secrets + OIDC | Minimal | Best practice. Use OIDC federation instead of stored secrets |

## Caller Validation

Restrict which repositories can call reusable workflows to prevent unauthorized usage.

### Unrestricted Caller (Default Behavior)

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy
on:
  workflow_call:
    # No caller restrictions
```

**Risk**: ANY repository in the organization or public workflows can call this workflow.

**Attack Vector**: Attacker forks repository, calls privileged reusable workflow with malicious inputs.

### Restricted Caller with Runtime Validation

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: choice
        options: [dev, staging, production]

permissions:
  contents: read
  id-token: write

jobs:
  validate-caller:
    runs-on: ubuntu-latest
    steps:
      - name: Validate caller repository
        run: |
          ALLOWED_REPOS=(
            "org/service-a"
            "org/service-b"
            "org/service-c"
          )

          CALLER_REPO="${{ github.repository }}"

          for repo in "${ALLOWED_REPOS[@]}"; do
            if [[ "$CALLER_REPO" == "$repo" ]]; then
              echo "Authorized caller: $CALLER_REPO"
              exit 0
            fi
          done

          echo "::error::Unauthorized caller: $CALLER_REPO"
          exit 1

  deploy:
    runs-on: ubuntu-latest
    needs: validate-caller
    environment: ${{ inputs.environment }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - run: ./scripts/deploy.sh ${{ inputs.environment }}
```

### Organization-Level Caller Validation

```yaml
# .github/workflows/reusable-security-scan.yml
name: Reusable Security Scan
on:
  workflow_call:

permissions:
  contents: read
  security-events: write

jobs:
  validate-caller:
    runs-on: ubuntu-latest
    steps:
      - name: Validate organization membership
        run: |
          CALLER_REPO="${{ github.repository }}"
          CALLER_ORG="${CALLER_REPO%%/*}"
          ALLOWED_ORG="your-org"

          if [[ "$CALLER_ORG" != "$ALLOWED_ORG" ]]; then
            echo "::error::Only $ALLOWED_ORG repositories can use this workflow"
            exit 1
          fi

  scan:
    runs-on: ubuntu-latest
    needs: validate-caller
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: aquasecurity/trivy-action@84384bd6e777ef152729993b8145ea352e9dd3ef  # 0.17.0
        with:
          scan-type: 'fs'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - uses: github/codeql-action/upload-sarif@cdcdbb579706841c47f7063dda365e292e5cad7a  # v2.13.4
        with:
          sarif_file: 'trivy-results.sarif'
```

## Pinning Reusable Workflows

Always pin reusable workflow references to full SHA to prevent supply chain attacks.

### Dangerous: Branch or Tag Reference

```yaml
# DO NOT USE - SUPPLY CHAIN RISK
jobs:
  deploy:
    uses: org/workflows/.github/workflows/deploy.yml@main
    # RISK: 'main' branch can be modified with malicious code
```

**Attack Vector**:

1. Attacker compromises upstream repository
2. Modifies workflow on `main` branch to exfiltrate secrets
3. All callers automatically use compromised workflow
4. Secrets stolen from all repositories

### Safe: SHA-Pinned Reference

```yaml
jobs:
  deploy:
    uses: org/workflows/.github/workflows/deploy.yml@a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0  # v1.2.3
    with:
      environment: production
    secrets:
      wif_provider: ${{ secrets.WIF_PROVIDER }}
      wif_service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
```

**SHA Pinning Benefits**:

1. Immutable reference to specific workflow version
2. Prevents supply chain attacks from upstream modifications
3. Version comment for readability
4. Dependabot can update to new SHAs automatically

### Local Reusable Workflow Pinning

For reusable workflows in the same repository, pin to SHA for production workflows.

**Development**: Can use relative path

```yaml
jobs:
  test:
    uses: ./.github/workflows/reusable-test.yml
    # Same repository, current commit
```

**Production**: Pin to SHA

```yaml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml@b4ffde65f46336ab88eb53be808477a3936bae11  # v1.2.3
    with:
      environment: production
```

### Dependabot Configuration for Reusable Workflows

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      reusable-workflows:
        patterns:
          - "org/workflows/*"
        update-types:
          - "minor"
          - "patch"
```

Dependabot will create PRs to update reusable workflow SHAs automatically.

## Complete Secure Reusable Workflow Example

```yaml
# .github/workflows/reusable-deploy-secure.yml
name: Secure Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
