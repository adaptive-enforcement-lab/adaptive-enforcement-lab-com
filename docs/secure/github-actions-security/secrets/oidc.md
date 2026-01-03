---
title: OIDC Federation Patterns
description: >-
  Secretless authentication to cloud providers using OpenID Connect federation.
  AWS, GCP, and Azure examples with subject claim patterns and trust policies.
tags:
  - github-actions
  - security
  - oidc
  - secrets
  - cloud
---

# OIDC Federation Patterns

Eliminate stored credentials entirely. OIDC federation replaces long-lived secrets with short-lived tokens tied to workflow context.

!!! success "The Win"

    OIDC federation means zero stored secrets for cloud authentication. No rotation burden, no credential sprawl, no leaked keys in logs. Tokens expire in minutes and are cryptographically bound to your repository, branch, and commit.

## What is OIDC Federation?

OpenID Connect (OIDC) allows GitHub Actions to authenticate to cloud providers without storing credentials as secrets.

**How It Works**:

1. GitHub Actions requests OIDC token via `id-token: write` permission
2. GitHub generates short-lived JWT with workflow claims (repo, branch, commit, etc.)
3. Workflow presents JWT to cloud provider's token exchange endpoint
4. Cloud provider validates claims against trust policy
5. Cloud provider issues temporary credentials (15 minutes to 1 hour)
6. Workflow uses temporary credentials to access cloud resources

**Key Benefits**:

- **No stored secrets**: Credentials never stored in GitHub
- **Short-lived tokens**: Expire in minutes, not years
- **Cryptographic binding**: Token tied to specific workflow context
- **Automatic rotation**: New token for every workflow run
- **Audit trail**: Cloud provider logs include workflow identity
- **Reduced attack surface**: Compromised workflow cannot exfiltrate long-lived credentials

## OIDC Token Claims

GitHub OIDC tokens include claims identifying the workflow context.

**Standard Claims**:

| Claim | Example | Description |
| ----- | ------- | ----------- |
| `sub` | `repo:org/repo:ref:refs/heads/main` | Subject identifier (most important for trust policies) |
| `aud` | `https://github.com/org` | Audience (usually organization or repo URL) |
| `iss` | `https://token.actions.githubusercontent.com` | Issuer (GitHub Actions) |
| `repository` | `org/repo` | Repository name |
| `repository_owner` | `org` | Organization or user |
| `ref` | `refs/heads/main` | Git ref that triggered workflow |
| `sha` | `abc123...` | Commit SHA |
| `workflow` | `CI` | Workflow name |
| `job_workflow_ref` | `org/repo/.github/workflows/ci.yml@refs/heads/main` | Workflow file reference |
| `environment` | `production` | Environment name (if used) |

## Subject Claim Patterns

The `sub` claim determines which workflows can assume cloud roles. Design subject patterns for least privilege.

### Repository-Level Trust

**Pattern**: Allow any workflow in specific repository

**Subject**: `repo:org/repo-name:*`

**Use Case**: All workflows in repository can access cloud resources

**Risk**: Any workflow file change can access credentials

**Example**:

```text
repo:adaptive-enforcement-lab/api-service:*
```

### Branch-Level Trust

**Pattern**: Allow workflows from specific branch only

**Subject**: `repo:org/repo-name:ref:refs/heads/main`

**Use Case**: Only main branch deployments

**Risk**: Lower risk, but all main workflows have access

**Example**:

```text
repo:adaptive-enforcement-lab/api-service:ref:refs/heads/main
```

### Environment-Level Trust (Recommended)

**Pattern**: Allow workflows targeting specific environment

**Subject**: `repo:org/repo-name:environment:production`

**Use Case**: Production deployments with approval gates

**Risk**: Lowest risk, combined with environment protection rules

**Example**:

```text
repo:adaptive-enforcement-lab/api-service:environment:production
```

### Pull Request Protection

**Pattern**: Block pull requests from assuming role

**Subject**: `repo:org/repo-name:ref:refs/heads/*` (excludes `refs/pull/*`)

**Use Case**: Prevent fork PRs from accessing production

**Risk**: Blocks legitimate PR workflows that need cloud access

**Example Trust Policy** (AWS):

```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": "repo:adaptive-enforcement-lab/api-service:ref:refs/heads/*"
  }
}
```

## AWS OIDC Federation

AWS uses IAM OIDC identity providers and trust policies to validate GitHub tokens.

### Setup Process

#### Step 1: Create OIDC Identity Provider

1. AWS Console → IAM → Identity providers → Add provider
2. Provider type: OpenID Connect
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Click "Add provider"

#### Step 2: Create IAM Role with Trust Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:adaptive-enforcement-lab/api-service:environment:production"
        }
      }
    }
  ]
}
```

**Key Elements**:

- `Federated`: ARN of OIDC provider created in Step 1
- `aud`: Must match audience claim (`sts.amazonaws.com`)
- `sub`: Subject pattern (environment-level recommended)

#### Step 3: Attach Permissions Policy

Attach IAM policy defining cloud resource permissions (S3, EC2, etc.)

**Example** (S3 deployment):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-deployment-bucket",
        "arn:aws:s3:::my-deployment-bucket/*"
      ]
    }
  ]
}
```

### Workflow Example

```yaml
name: Deploy to AWS
on:
  push:
    branches: [main]

permissions:
  id-token: write  # Required for OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production  # Matches subject claim
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      # aws-actions/configure-aws-credentials v4.0.1
      - uses: aws-actions/configure-aws-credentials@5fd3084fc36e372ff1fff382a39b10d03659f355
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsDeployRole
          aws-region: us-east-1

      # Temporary credentials now available
      - run: aws s3 sync ./dist s3://my-deployment-bucket
```

**Permissions**: `id-token: write` grants permission to request OIDC token. `contents: read` for checkout.

**Security**: Token expires in 1 hour. Role only assumable by production environment workflows.

## GCP Workload Identity Federation

GCP uses Workload Identity Pools and Providers to validate GitHub tokens.

### Setup Process

#### Step 1: Create Workload Identity Pool

```bash
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool"
```

#### Step 2: Create Workload Identity Provider

```bash
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --issuer-uri=https://token.actions.githubusercontent.com \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository_owner == 'adaptive-enforcement-lab'"
```

**Key Configuration**:

- `issuer-uri`: GitHub OIDC token issuer
- `attribute-mapping`: Maps GitHub claims to GCP attributes
- `attribute-condition`: Additional filtering (organization-level trust)

#### Step 3: Grant Service Account Access

```bash
gcloud iam service-accounts add-iam-policy-binding deploy@my-project.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/github-pool/attribute.repository/adaptive-enforcement-lab/api-service"
```

**Attribute Filtering** (environment-level):

```bash
--member="principalSet://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/github-pool/attribute.repository/adaptive-enforcement-lab/api-service/attribute.environment/production"
```

### Workflow Example

```yaml
name: Deploy to GCP
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
  deploy-aws:
    runs-on: ubuntu-latest
    environment: production-aws
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      # aws-actions/configure-aws-credentials v4.0.1
      - uses: aws-actions/configure-aws-credentials@5fd3084fc36e372ff1fff382a39b10d03659f355
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1

      - run: aws s3 sync ./dist s3://aws-bucket

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

**AWS**: `sts.amazonaws.com`
**GCP**: Workload Identity Provider URL
**Azure**: `api://AzureADTokenExchange`

**Minimize cloud permissions**: Grant only resources required for deployment. Use resource-level restrictions.

**Example** (S3 bucket access only):

```json
"Resource": [
  "arn:aws:s3:::my-specific-bucket",
  "arn:aws:s3:::my-specific-bucket/*"
]
```

**Monitor assume role events**: Set up CloudTrail (AWS), Cloud Logging (GCP), or Activity Log (Azure) alerts for role assumption.

**Use short token expiration**: Default 1 hour maximum. Reduce if workflows complete faster.

**AWS Example**:

```yaml
- uses: aws-actions/configure-aws-credentials@5fd3084fc36e372ff1fff382a39b10d03659f355
  with:
    role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
    aws-region: us-east-1
    role-duration-seconds: 900  # 15 minutes
```

**Audit trust policies regularly**: Review cloud IAM policies quarterly. Remove unused subject patterns.

**Test with dry-run deployments**: Verify OIDC configuration without production impact.

```yaml
- run: aws s3 sync ./dist s3://bucket --dryrun
```

## Troubleshooting

### Error: "Not authorized to perform sts:AssumeRoleWithWebIdentity"

**Cause**: Trust policy subject claim mismatch

**Fix**: Verify subject claim matches workflow context

**Debug**:

```yaml
- run: |
    curl -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
      "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=sts.amazonaws.com" | \
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

**AWS Fix**: Ensure `aud` is `sts.amazonaws.com` in trust policy

**GCP Fix**: Verify Workload Identity Provider URL matches

**Azure Fix**: Audience should be `api://AzureADTokenExchange`

### Error: "Token expired"

**Cause**: OIDC token lifetime exceeded (15 minutes default)

**Fix**: Request token immediately before cloud authentication step

```yaml
# WRONG - token may expire before use
- uses: aws-actions/configure-aws-credentials@5fd3084fc36e372ff1fff382a39b10d03659f355
- run: sleep 1000  # Long-running task
- run: aws s3 sync ...  # Token expired

# RIGHT - authenticate immediately before use
- run: ./build.sh  # Long-running task
- uses: aws-actions/configure-aws-credentials@5fd3084fc36e372ff1fff382a39b10d03659f355
- run: aws s3 sync ...  # Token fresh
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

See [Workflow Triggers Security](../workflows/triggers.md) for fork workflow patterns.

## Migration from Stored Secrets

Replace long-lived credentials with OIDC federation.

**Before** (stored secrets):

```yaml
- run: aws s3 sync ./dist s3://bucket
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**After** (OIDC):

```yaml
permissions:
  id-token: write

- uses: aws-actions/configure-aws-credentials@5fd3084fc36e372ff1fff382a39b10d03659f355
  with:
    role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
    aws-region: us-east-1

- run: aws s3 sync ./dist s3://bucket
```

**Migration Checklist**:

- [ ] Set up cloud OIDC provider (AWS, GCP, Azure)
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

- **[Secret Rotation Patterns](rotation.md)**: Automated rotation for remaining long-lived secrets
- **[Secret Scanning Integration](scanning.md)**: Detect leaked credentials with push protection
- **[Environment Protection](../workflows/environments.md)**: Combine OIDC with approval gates

## Quick Reference

### Cloud Provider OIDC Actions

| Provider | Action | Current SHA-Pinned Version |
| -------- | ------ | -------------------------- |
| **AWS** | `aws-actions/configure-aws-credentials` | `@5fd3084fc36e372ff1fff382a39b10d03659f355` (v4.0.1) |
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
