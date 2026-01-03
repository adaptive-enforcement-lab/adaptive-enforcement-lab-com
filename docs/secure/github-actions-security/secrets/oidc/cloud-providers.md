---
title: Cloud Provider OIDC Patterns
description: >-
  GCP Workload Identity Federation setup, Azure federated credentials configuration, and secretless cloud authentication patterns
---

!!! note "Environment-Level Trust Recommended"

    Use environment-level subject claims for production OIDC access. Combine GitHub environment protection with OIDC trust policies to require approval gates before assuming cloud roles. This prevents unauthorized deployments.

## GCP Workload Identity Federation

```yaml
      # google-github-actions/auth v2.1.0
      - uses: google-github-actions/auth@f112390a2df9932162083945e46d439060d66ec2
        with:
          workload_identity_provider: 'projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
          service_account: 'deploy@my-project.iam.gserviceaccount.com'

      # Temporary credentials now available
      - run: gcloud storage cp ./dist/* gs://my-deployment-bucket/
```

## Azure Federated Credentials

Azure uses App Registrations with federated credentials to validate GitHub tokens.

### Setup Process

#### Step 1: Create App Registration

1. Azure Portal → Azure Active Directory → App registrations → New registration
2. Name: `GitHubActionsDeployment`
3. Supported account types: Single tenant
4. Click "Register"
5. Note the Application (client) ID and Directory (tenant) ID

#### Step 2: Add Federated Credential

1. App registration → Certificates & secrets → Federated credentials → Add credential
2. Federated credential scenario: GitHub Actions deploying Azure resources
3. Organization: `adaptive-enforcement-lab`
4. Repository: `api-service`
5. Entity type: Environment
6. Environment name: `production`
7. Name: `production-deployment`
8. Click "Add"

**Subject Claim Generated**:

```text
repo:adaptive-enforcement-lab/api-service:environment:production
```

#### Step 3: Grant Azure Permissions

Assign Azure RBAC role to service principal:

```bash
az role assignment create \
  --assignee <application-client-id> \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/my-resource-group"
```

### Workflow Example

```yaml
name: Deploy to Azure
on:
  push:
    branches: [main]

permissions:
  id-token: write  # Required for OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      # azure/login v1.5.1
      - uses: azure/login@8c334a195cbb38e46038007b304988d888bf676a
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      # Temporary credentials now available
      - run: az storage blob upload-batch --destination my-container --source ./dist
```

**Secrets**: Client ID, Tenant ID, and Subscription ID are not sensitive (they're identifiers, not credentials). Store as repository secrets or configuration variables.

## Multi-Cloud OIDC Pattern

Use single workflow to deploy to multiple cloud providers with OIDC.

```yaml
name: Multi-Cloud Deploy
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy-gcp:
    runs-on: ubuntu-latest
    environment: production-gcp
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      # google-github-actions/auth v2.1.0
      - uses: google-github-actions/auth@f112390a2df9932162083945e46d439060d66ec2
        with:
          workload_identity_provider: 'projects/123/locations/global/workloadIdentityPools/github/providers/github'
          service_account: 'deploy@project.iam.gserviceaccount.com'

      - run: gcloud storage cp ./dist/* gs://gcp-bucket/

  deploy-azure:
    runs-on: ubuntu-latest
    environment: production-azure
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      # azure/login v1.5.1
      - uses: azure/login@8c334a195cbb38e46038007b304988d888bf676a
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - run: az storage blob upload-batch --destination my-container --source ./dist
```

**Pattern**: Separate jobs per cloud provider. Each job uses environment-specific OIDC configuration.

## Security Best Practices

**Use environment-level subject claims**: Combine OIDC with GitHub environment protection for approval gates.

```yaml
environment: production  # Requires approval, matches sub claim
```

**Restrict by branch**: Block pull requests from assuming cloud roles.

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:org/repo:ref:refs/heads/*"
}
```

**Validate audience**: Always check `aud` claim matches expected value.

**GCP**: Workload Identity Provider URL
**Azure**: `api://AzureADTokenExchange`

**Minimize cloud permissions**: Grant only resources required for deployment. Use resource-level restrictions.

**Example** (GCP Storage bucket access only):

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:deploy@project.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin" \
  --condition="resource.name.startsWith('projects/_/buckets/my-specific-bucket')"
```

**Monitor assume role events**: Set up Cloud Logging (GCP) or Activity Log (Azure) alerts for role assumption.

**Use short token expiration**: Default 1 hour maximum. Reduce if workflows complete faster.

**GCP Example**: Tokens are short-lived by default (1 hour). No additional configuration required.

**Audit trust policies regularly**: Review cloud IAM policies quarterly. Remove unused subject patterns.

**Test with dry-run deployments**: Verify OIDC configuration without production impact.

```bash
# GCP dry-run example
gcloud storage cp ./dist/* gs://bucket --dry-run
```

## Troubleshooting

### Error: "Not authorized to impersonate service account"

**Cause**: Trust policy subject claim mismatch or insufficient permissions

**Fix**: Verify subject claim matches workflow context

**Debug OIDC Token**:

```yaml
- run: |
    curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL" | \
      jq -R 'split(".") | .[1] | @base64d | fromjson'
```

This decodes the OIDC token to inspect claims.

**Common Mismatches**:

| Expected | Actual | Fix |
| -------- | ------ | --- |
| `environment:production` | `ref:refs/heads/main` | Add `environment: production` to job |
| `ref:refs/heads/main` | `ref:refs/pull/123/merge` | Change trust policy to allow PR refs or use branch deployments |
| `repo:org/repo` | `repo:org/fork` | Restrict trust policy to specific repository |

### Error: "Audience validation failed"

**Cause**: Audience claim does not match expected value

**GCP Fix**: Verify Workload Identity Provider URL matches exactly

**Azure Fix**: Audience should be `api://AzureADTokenExchange`

### Error: "Token expired"

**Cause**: OIDC token lifetime exceeded (15 minutes default)

**Fix**: Request token immediately before cloud authentication step

```yaml
# WRONG - token may expire before use
- uses: google-github-actions/auth@f112390a2df9932162083945e46d439060d66ec2
- run: sleep 1000  # Long-running task
- run: gcloud storage cp ...  # Token expired

# RIGHT - authenticate immediately before use
- run: ./build.sh  # Long-running task
- uses: google-github-actions/auth@f112390a2df9932162083945e46d439060d66ec2
- run: gcloud storage cp ...  # Token fresh
```

### Error: "Workload identity pool does not exist"

**Cause**: Workload Identity Provider URL incorrect or pool deleted

**GCP Fix**: Verify pool and provider names match exactly

```bash
gcloud iam workload-identity-pools describe github-pool --location=global
```

### Workflow Fails on Forked PRs

**Cause**: Fork workflows cannot access `id-token: write` permission by default

**Expected Behavior**: Forks should not access production OIDC credentials

**Fix**: Use `pull_request` trigger (not `pull_request_target`) to block secret access

```yaml
on:
  pull_request:  # Fork workflows run without secrets or OIDC
    branches: [main]
```

See [Workflow Triggers Security](../../workflows/triggers/index.md) for fork workflow patterns.

## Migration from Stored Secrets

Replace long-lived credentials with OIDC federation.

**Before** (stored secrets):

```yaml
- run: gcloud storage cp ./dist/* gs://bucket/
  env:
    GOOGLE_APPLICATION_CREDENTIALS_JSON: ${{ secrets.GCP_SA_KEY }}
```

**After** (OIDC):

```yaml
permissions:
  id-token: write

- uses: google-github-actions/auth@f112390a2df9932162083945e46d439060d66ec2
  with:
    workload_identity_provider: 'projects/123/locations/global/workloadIdentityPools/github/providers/github'
    service_account: 'deploy@project.iam.gserviceaccount.com'

- run: gcloud storage cp ./dist/* gs://bucket/
```

**Migration Checklist**:

- [ ] Set up cloud OIDC provider (GCP, Azure)
- [ ] Create cloud role/service account with permissions policy
- [ ] Configure trust policy with subject claim pattern
- [ ] Add `permissions: id-token: write` to workflow
- [ ] Test OIDC authentication in staging environment
- [ ] Update production workflow to use OIDC
- [ ] Delete stored secrets from GitHub
- [ ] Revoke long-lived cloud credentials
- [ ] Document OIDC configuration for team

## Next Steps

Ready to secure your workflows? Continue with:

- **[Secret Rotation Patterns](../rotation/index.md)**: Automated rotation for remaining long-lived secrets
- **[Secret Scanning Integration](../scanning/index.md)**: Detect leaked credentials with push protection
- **[Environment Protection](../../workflows/environments/index.md)**: Combine OIDC with approval gates

## Quick Reference

### Cloud Provider OIDC Actions

| Provider | Action | Current SHA-Pinned Version |
| -------- | ------ | -------------------------- |
| **GCP** | `google-github-actions/auth` | `@f112390a2df9932162083945e46d439060d66ec2` (v2.1.0) |
| **Azure** | `azure/login` | `@8c334a195cbb38e46038007b304988d888bf676a` (v1.5.1) |

### Subject Claim Patterns

| Pattern | Subject Example | Use Case |
| ------- | --------------- | -------- |
| **Repository** | `repo:org/repo:*` | Any workflow in repo |
| **Branch** | `repo:org/repo:ref:refs/heads/main` | Main branch only |
| **Environment** | `repo:org/repo:environment:production` | Production deployments (recommended) |
| **Pull Request** | `repo:org/repo:pull_request` | PR workflows (use with caution) |

### Required Workflow Permission

```yaml
permissions:
  id-token: write  # Request OIDC token
  contents: read   # Checkout code
```

---

!!! success "Zero Secrets, Maximum Security"

    OIDC federation is the gold standard for cloud authentication. No rotation, no sprawl, no leaked credentials in logs. Default to OIDC for every cloud integration. Stored secrets should be the rare exception, not the default pattern.
