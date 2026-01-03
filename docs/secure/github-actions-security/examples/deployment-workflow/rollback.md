---
title: Manual Rollback and Security Checklist
description: >-
  Rollback procedures, security checklist, and common deployment mistakes
---


          gcloud run deploy ${{ vars.SERVICE_NAME }}-dev \
            --image "${IMAGE_URL}" \
            --region ${{ vars.GCP_REGION }} \
            --platform managed \
            --allow-unauthenticated \
            --min-instances 0 \
            --max-instances 5 \
            --set-env-vars "ENVIRONMENT=dev"

# Job 3: Deploy to staging (requires dev success)

  deploy-staging:
    needs: [build, deploy-dev]
    runs-on: ubuntu-latest
    # SECURITY: Environment protection (optional reviewers, 2-minute wait timer)
    environment:
      name: staging
      url: <https://staging-${{> vars.SERVICE_NAME }}.example.com
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT_STAGING }}

      - uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      - name: Deploy to Cloud Run (Staging)
        run: |
          IMAGE_URL="${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}@${{ needs.build.outputs.image-digest }}"

          gcloud run deploy ${{ vars.SERVICE_NAME }}-staging \
            --image "${IMAGE_URL}" \
            --region ${{ vars.GCP_REGION }} \
            --platform managed \
            --allow-unauthenticated \
            --min-instances 0 \
            --max-instances 10 \
            --set-env-vars "ENVIRONMENT=staging"

      - name: Run integration tests
        run: |
          SERVICE_URL=$(gcloud run services describe ${{ vars.SERVICE_NAME }}-staging \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(status.url)')

          # Run integration test suite
          curl -f "${SERVICE_URL}/health"
          # Add comprehensive integration tests here

# Job 4: Deploy to production (requires staging success + approval)

  deploy-production:
    needs: [build, deploy-staging]
    runs-on: ubuntu-latest
    # SECURITY: Environment protection (required reviewers, 5-minute wait timer)
    environment:
      name: production
      url: https://${{ vars.SERVICE_NAME }}.example.com
    permissions:
      contents: read
      id-token: write
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT_PRODUCTION }}

      - uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      - name: Deploy to Cloud Run (Production)
        run: |
          IMAGE_URL="${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}@${{ needs.build.outputs.image-digest }}"

          gcloud run deploy ${{ vars.SERVICE_NAME }} \
            --image "${IMAGE_URL}" \
            --region ${{ vars.GCP_REGION }} \
            --platform managed \
            --allow-unauthenticated \
            --min-instances 1 \
            --max-instances 100 \
            --set-env-vars "ENVIRONMENT=production" \
            --no-traffic

      - name: Verify and promote
        run: |
          # Health check
          LATEST_REVISION=$(gcloud run revisions list \
            --service ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(name)' \
            --limit 1)

          # Route traffic
          gcloud run services update-traffic ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --to-revisions "${LATEST_REVISION}=100"

```

**Environment Protection Configuration**:

- **Dev**: No protection (auto-deploy)
- **Staging**: 2-minute wait timer, optional reviewers
- **Production**: Required reviewers (2+), 5-minute wait timer, `main` branch only

## Manual Rollback Workflow

Separate workflow for emergency rollback with approval gate.

```yaml
name: Emergency Rollback
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rollback'
        required: true
        type: choice
        options:
          - staging
          - production
      revision:
        description: 'Revision name to rollback to (leave empty for previous)'
        required: false
        type: string

permissions:
  contents: read

jobs:
  rollback:
    runs-on: ubuntu-latest
    # SECURITY: Require approval for production rollbacks
    environment: ${{ github.event.inputs.environment }}
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      # SECURITY: List available revisions for visibility
      - name: List available revisions
        run: |
          echo "Available revisions for ${{ vars.SERVICE_NAME }}-${{ github.event.inputs.environment }}:"
          gcloud run revisions list \
            --service ${{ vars.SERVICE_NAME }}-${{ github.event.inputs.environment }} \
            --region ${{ vars.GCP_REGION }} \
            --limit 10

      - name: Determine rollback target
        id: target
        run: |
          SERVICE_NAME="${{ vars.SERVICE_NAME }}-${{ github.event.inputs.environment }}"

          if [[ -n "${{ github.event.inputs.revision }}" ]]; then
            TARGET_REVISION="${{ github.event.inputs.revision }}"
          else
            # Get previous revision (second in list)
            TARGET_REVISION=$(gcloud run revisions list \
              --service "${SERVICE_NAME}" \
              --region ${{ vars.GCP_REGION }} \
              --format 'value(name)' \
              --limit 2 | tail -n 1)
          fi

          echo "target-revision=${TARGET_REVISION}" >> $GITHUB_OUTPUT
          echo "Rolling back to: ${TARGET_REVISION}"

      # SECURITY: Perform rollback
      - name: Execute rollback
        run: |
          SERVICE_NAME="${{ vars.SERVICE_NAME }}-${{ github.event.inputs.environment }}"
          TARGET_REVISION="${{ steps.target.outputs.target-revision }}"

          gcloud run services update-traffic "${SERVICE_NAME}" \
            --region ${{ vars.GCP_REGION }} \
            --to-revisions "${TARGET_REVISION}=100"

          echo "Rollback complete: 100% traffic to ${TARGET_REVISION}"

      - name: Verify rollback
        run: |
          SERVICE_NAME="${{ vars.SERVICE_NAME }}-${{ github.event.inputs.environment }}"

          SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(status.url)')

          # Health check
          for i in {1..5}; do
            if curl -f -s -o /dev/null "${SERVICE_URL}/health"; then
              echo "Rollback health check passed"
              exit 0
            fi
            echo "Health check attempt $i failed, retrying..."
            sleep 10
          done

          echo "::error::Rollback health check failed"
          exit 1
```

## Security Checklist

Use this checklist to verify your deployment workflow follows security best practices.

### OIDC Security

- [ ] OIDC authentication configured (no stored service account keys)
- [ ] Workload Identity Federation trust policy restricts by environment
- [ ] Subject claim uses environment-level trust (`environment:production`)
- [ ] Token lifetime set to minimum required (default: 1 hour)
- [ ] Trust policy blocks pull requests from assuming role
- [ ] Service accounts follow least privilege (separate per environment)

### Environment Security

- [ ] Production environment configured with required reviewers
- [ ] Wait timer enabled (recommended: 5+ minutes for production)
- [ ] Deployment branches restricted (main/release branches only)
- [ ] Environment secrets used for production credentials
- [ ] Environment URLs configured for deployment tracking
- [ ] Approval gate tested and verified

### Deployment Security

- [ ] Container images scanned for vulnerabilities before deployment
- [ ] Images signed with keyless signing (Cosign)
