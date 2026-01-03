---
title: Repository Access and Workflow Restrictions
description: >-
  Repository access configuration, API-based setup, and workflow restrictions
---

# Configure workflow restrictions for runner group

set -euo pipefail

ORG="your-organization"
RUNNER_GROUP_ID="123"
ALLOWED_WORKFLOWS=(
  "${ORG}/production-api/.github/workflows/deploy-production.yml@refs/heads/main"
  "${ORG}/production-web/.github/workflows/deploy-production.yml@refs/heads/main"
)

# Enable workflow restrictions

gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  "/orgs/${ORG}/actions/runner-groups/${RUNNER_GROUP_ID}" \
  -f restricted_to_workflows=true

# Add allowed workflows

for workflow in "${ALLOWED_WORKFLOWS[@]}"; do
  gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/orgs/${ORG}/actions/runner-groups/${RUNNER_GROUP_ID}/workflows" \
    -f workflow="${workflow}"

  echo "Allowed workflow: ${workflow}"
done

```

### Workflow Restriction Verification

Audit which workflows can access which runner groups.

```bash
#!/bin/bash
# Audit runner group workflow restrictions

set -euo pipefail

ORG="your-organization"

echo "==> Auditing runner group workflow restrictions for ${ORG}"

gh api "/orgs/${ORG}/actions/runner-groups" --paginate --jq '.runner_groups[]' | while read -r group; do
  GROUP_ID=$(echo "$group" | jq -r '.id')
  GROUP_NAME=$(echo "$group" | jq -r '.name')
  RESTRICTED=$(echo "$group" | jq -r '.restricted_to_workflows')

  echo ""
  echo "Runner Group: ${GROUP_NAME}"
  echo "  Workflow Restrictions: ${RESTRICTED}"

  if [[ "$RESTRICTED" == "true" ]]; then
    # List allowed workflows
    gh api "/orgs/${ORG}/actions/runner-groups/${GROUP_ID}/workflows" --paginate \
      | jq -r '.workflows[].path' \
      | while read -r workflow; do
        echo "  - ${workflow}"
      done
  else
    echo "  - All workflows allowed"
  fi
done
```

## Runner Group Security Best Practices

### Principle 1: Deny by Default

Default to no access. Explicitly grant repository and workflow access only when justified.

**Implementation**:

- Create runner groups with "Selected repositories" access
- Enable workflow restrictions for sensitive runners
- Review access quarterly and revoke unused permissions

### Principle 2: Least Privilege Groups

Organize runners by sensitivity and grant minimal access.

**Implementation**:

- Separate development, staging, and production runner groups
- Production runners accessible only to production repositories
- Compliance runners accessible only to audited workflows

### Principle 3: Workflow Pinning

Pin allowed workflows to specific branches (typically `main` or `release/*`) to prevent bypass via malicious branches.

**Implementation**:

```yaml
Allowed workflows:
  - org/app/.github/workflows/deploy.yml@refs/heads/main  # Good
  - org/app/.github/workflows/deploy.yml@*  # Bad - any branch can execute
```

### Principle 4: Monitor Group Access

Alert on unauthorized runner group configuration changes.

**Implementation**:

```yaml
# .github/workflows/audit-runner-groups.yml
# Monitor runner group configuration changes

name: Audit Runner Groups
on:
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
  workflow_dispatch:

permissions:
  contents: read

jobs:
  audit-groups:
    runs-on: ubuntu-latest
    steps:
      - name: Audit runner groups
        env:
          GH_TOKEN: ${{ secrets.ORG_AUDIT_TOKEN }}
        run: |
          ORG="your-organization"

          # Expected configuration
          declare -A EXPECTED_GROUPS=(
            ["prod-runners"]="selected,restricted"
            ["dev-runners"]="selected,unrestricted"
            ["gpu-runners"]="selected,restricted"
          )

          # Audit actual configuration
          while IFS= read -r group; do
            GROUP_NAME=$(echo "$group" | jq -r '.name')
            VISIBILITY=$(echo "$group" | jq -r '.visibility')
            RESTRICTED=$(echo "$group" | jq -r '.restricted_to_workflows')

            EXPECTED="${EXPECTED_GROUPS[$GROUP_NAME]}"
            ACTUAL="${VISIBILITY},${RESTRICTED}"

            if [[ "$EXPECTED" != "$ACTUAL" ]]; then
              echo "::error::Runner group ${GROUP_NAME} misconfigured: expected ${EXPECTED}, got ${ACTUAL}"
              exit 1
            fi
          done < <(gh api "/orgs/${ORG}/actions/runner-groups" --jq '.runner_groups[]')

          echo "All runner groups properly configured"
```

### Principle 5: Document Group Purpose

Maintain documentation for each runner group with purpose, trust level, and access rationale.

**Implementation**:

```yaml
# .github/runner-groups.yml
# Runner group configuration documentation

groups:
  - name: prod-runners
    purpose: Production deployment workflows only
    trust_level: High
    network_access: Production VPC
    allowed_repos:
      - production-api
      - production-web
    allowed_workflows:
      - .github/workflows/deploy-production.yml
    approval_required: true
    rationale: Production deployments require manual approval and audit trail

  - name: dev-runners
    purpose: Development and testing workflows
    trust_level: Low
    network_access: Development VPC
    allowed_repos: All private repositories
    allowed_workflows: All workflows
    approval_required: false
    rationale: Isolated network with no production access
```

## Common Misconfigurations

### Misconfiguration 1: All Repositories Access for Production Runners

**Problem**: Production runners available to all repositories.

**Risk**: Compromised development repository can execute on production runners with production network access.

**Fix**:

```yaml
# Before (insecure)
Group: prod-runners
Access: All repositories

# After (secure)
Group: prod-runners
Access: Selected repositories
Repositories:
  - production-api
  - production-web
```

### Misconfiguration 2: No Workflow Restrictions

**Problem**: Production runners accessible to any workflow file in allowed repositories.

**Risk**: Malicious developer adds new workflow file that targets production runners.

**Fix**:

```yaml
# Before (insecure)
Group: prod-runners
Workflow restrictions: None

# After (secure)
Group: prod-runners
Workflow restrictions: Selected workflows
Allowed workflows:
  - org/production-api/.github/workflows/deploy-production.yml@refs/heads/main
```

### Misconfiguration 3: Wildcard Branch References

**Problem**: Workflow restrictions allow any branch reference.

**Risk**: Attacker creates malicious branch with modified workflow that bypasses security controls.

**Fix**:

```yaml
# Before (insecure)
Allowed workflows:
  - org/app/.github/workflows/deploy.yml@*

# After (secure)
