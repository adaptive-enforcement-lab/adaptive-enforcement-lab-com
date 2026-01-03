---
title: Deployment Gates Patterns
description: >-
  Production triple gates, fork PR previews, and canary deployment patterns
---

1. Workflow waits 15 minutes (wait timer)
2. Two reviewers must approve
3. Branch policy verified (`main` only)
4. Deployment executes
5. Slack notification sent

### Pattern 2: Fork PR Preview with Approval

**Protection**: Required reviewers + OIDC + Minimal permissions

**Configuration**:

- Required reviewers: 1 maintainer
- Deployment branches: All branches (for PR previews)
- OIDC federation: No stored secrets

**Workflow**:

```yaml
name: PR Preview
on:
  pull_request_target:
    branches: [main]

permissions:
  contents: read
  pull-requests: write
  id-token: write

jobs:
  deploy-preview:
    runs-on: ubuntu-latest
    environment: pr-previews
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          ref: ${{ github.event.pull_request.head.sha }}

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Deploy preview
        id: deploy
        run: |
          PREVIEW_URL=$(./scripts/deploy-preview.sh pr-${{ github.event.pull_request.number }})
          echo "url=$PREVIEW_URL" >> $GITHUB_OUTPUT

      - uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            await github.rest.issues.createComment({
              issue_number: context.payload.pull_request.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `Preview deployed: ${{ steps.deploy.outputs.url }}`
            });
```

**Protection Behavior**:

1. Fork PR triggers `pull_request_target`
2. Workflow pauses for maintainer approval
3. Maintainer reviews PR, approves deployment
4. Preview deploys with OIDC credentials
5. Preview URL posted as PR comment

### Pattern 3: Canary Deployment with Wait Timer

**Protection**: Wait timer + Health checks + Rollback

**Configuration**:

- Wait timer: 10 minutes
- Deployment branches: `main`
- Health check validation

**Workflow**:

```yaml
name: Canary Deploy
on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  deploy-canary:
    runs-on: ubuntu-latest
    environment:
      name: production-canary
      url: https://canary.example.com
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Deploy to canary
        run: ./scripts/deploy.sh canary

      - name: Wait for metrics
        run: sleep 600

      - name: Validate canary health
        id: health
        run: |
          HEALTH=$(./scripts/check-canary-health.sh)
          if [ "$HEALTH" != "healthy" ]; then
            echo "::error::Canary health check failed"
            exit 1
          fi

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-canary
    environment:
      name: production
      url: https://app.example.com
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}

      - name: Deploy to production
        run: ./scripts/deploy.sh production

      - name: Monitor deployment
        run: ./scripts/monitor-deployment.sh production 300
```

**Protection Flow**:

1. Deploy to canary environment
2. Wait timer delays 10 minutes
3. Health checks validate canary
4. If healthy, proceed to production environment
5. Production wait timer and reviewers apply
6. Production deployment executes with monitoring

## Environment Configuration via API

Automate environment configuration using GitHub CLI or REST API.

### Create Environment with Protection Rules

```bash
#!/bin/bash
# scripts/create-environment.sh

REPO="org/repo"
ENVIRONMENT="production"

# Create environment
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/environments/$ENVIRONMENT"

# Add required reviewers
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/environments/$ENVIRONMENT" \
  -f "reviewers[][type]=User" \
  -f "reviewers[][id]=12345" \
  -f "reviewers[][type]=Team" \
  -f "reviewers[][id]=67890" \
  -f "wait_timer=900" \
  -f "deployment_branch_policy[protected_branches]=true" \
  -f "deployment_branch_policy[custom_branch_policies]=false"
```

### Bulk Environment Setup

```bash
#!/bin/bash
# scripts/setup-environments.sh

REPO="org/repo"

# Development environment
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/environments/development" \
  -f "deployment_branch_policy[protected_branches]=false" \
  -f "deployment_branch_policy[custom_branch_policies]=true"

# Add custom branch policy for development
gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/environments/development/deployment-branch-policies" \
  -f "name=*"

# Staging environment
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/environments/staging" \
  -f "wait_timer=300" \
  -f "deployment_branch_policy[protected_branches]=false" \
  -f "deployment_branch_policy[custom_branch_policies]=true"

# Add branch policies for staging
for branch in main develop 'release/*'; do
  gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    "/repos/$REPO/environments/staging/deployment-branch-policies" \
    -f "name=$branch"
done

# Production environment
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/environments/production" \
  -f "wait_timer=900" \
  -f "deployment_branch_policy[protected_branches]=true" \
  -f "deployment_branch_policy[custom_branch_policies]=false"

# Add required reviewers (replace IDs)
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/environments/production" \
  -F "reviewers[][type]=User" \
  -F "reviewers[][id]=12345" \
  -F "reviewers[][type]=Team" \
  -F "reviewers[][id]=67890"
```

## Deployment Tracking

Environments provide deployment history and status tracking.

### Deployment Status API

```bash
#!/bin/bash
# scripts/check-deployment-status.sh

REPO="org/repo"
ENVIRONMENT="production"

# Get recent deployments
gh api \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/deployments?environment=$ENVIRONMENT&per_page=10" \
  --jq '.[] | {sha: .sha, environment: .environment, status: .statuses_url}'

# Get deployment status
DEPLOYMENT_ID="123456"
gh api \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/deployments/$DEPLOYMENT_ID/statuses" \
  --jq '.[] | {state: .state, created_at: .created_at, description: .description}'
```

### Monitor Active Deployments

```yaml
name: Deployment Monitor
on:
  schedule:
    - cron: '*/5 * * * *'

permissions:
  deployments: read

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - name: Check active deployments
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          ACTIVE=$(gh api \
            -H "Accept: application/vnd.github+json" \
            "/repos/${{ github.repository }}/deployments?environment=production&per_page=5" \
            --jq '[.[] | select(.updated_at > (now - 3600 | todate))] | length')

          if [ "$ACTIVE" -gt 2 ]; then
            echo "::warning::Multiple active deployments detected"
          fi

      - name: Alert on pending approvals
