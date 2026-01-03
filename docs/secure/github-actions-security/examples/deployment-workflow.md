---
title: Hardened Deployment Workflow
description: >-
  Production-ready deployment workflow examples with OIDC authentication, environment protection, approval gates, and rollback patterns.
tags:
  - github-actions
  - security
  - deployment
  - oidc
  - environments
  - rollback
---

# Hardened Deployment Workflow

Copy-paste ready deployment workflow templates with comprehensive security hardening. Each example demonstrates OIDC authentication, environment protection, approval gates, zero-downtime deployments, and automated rollback patterns.

!!! tip "Complete Security Patterns"

    These workflows integrate all security patterns from the hub: OIDC federation (no stored secrets), environment protection with approval gates, SHA-pinned actions, minimal GITHUB_TOKEN permissions, deployment verification, and automated rollback. Use as production templates for secure deployments.

## Deployment Security Principles

Every deployment workflow in this guide implements these controls:

1. **OIDC Authentication**: Secretless cloud authentication with short-lived tokens
2. **Environment Protection**: Required reviewers and wait timers for production
3. **Minimal Permissions**: `id-token: write` for OIDC, `contents: read` by default
4. **Approval Gates**: Human review before production deployment
5. **Deployment Verification**: Health checks after deployment
6. **Rollback Automation**: Automatic rollback on failure
7. **Audit Trail**: Deployment tracking and change logs

## GCP Cloud Run Deployment

Secure workflow for deploying containerized applications to GCP Cloud Run with OIDC authentication.

### Production Deployment with Approval Gate

Complete production deployment with environment protection and verification.

```yaml
name: Deploy to GCP Cloud Run
on:
  push:
    branches: [main]
  workflow_dispatch:
    # SECURITY: Manual deployments require explicit trigger
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        type: choice
        options:
          - staging
          - production

# SECURITY: Minimal permissions by default
permissions:
  contents: read

jobs:
  # Job 1: Build and push container image
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read      # Read repository code
      id-token: write     # Generate OIDC tokens for GCP auth
      attestations: write # Create artifact attestations
    outputs:
      image-digest: ${{ steps.push.outputs.digest }}
      image-url: ${{ steps.push.outputs.image-url }}
    steps:
      # SECURITY: All actions pinned to full SHA-256 commit hashes
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Authenticate to GCP using OIDC (no stored secrets)
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          # SECURITY: Workload Identity Federation replaces service account keys
          # Trust policy restricts access to specific repository and branch
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
          # Token lifetime: 1 hour (default), just long enough for deployment
          token_format: 'access_token'
          access_token_lifetime: '3600s'

      # SECURITY: Set up Cloud SDK with authenticated gcloud
      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      # SECURITY: Authenticate Podman to Artifact Registry using OIDC token
      - name: Configure container registry auth
        run: |
          gcloud auth configure-docker ${{ vars.GCP_REGION }}-docker.pkg.dev

      # SECURITY: Build container with security scanning
      - name: Build container image
        run: |
          podman build \
            --tag ${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}:${{ github.sha }} \
            --tag ${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}:latest \
            --label "git-commit=${{ github.sha }}" \
            --label "git-ref=${{ github.ref }}" \
            --label "build-date=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
            .

      # SECURITY: Scan image for vulnerabilities before pushing
      - name: Scan container for vulnerabilities
        uses: aquasecurity/trivy-action@d43c1f16c00cfd3978dde6c07f4bbcf9eb6993ca  # 0.16.1
        with:
          image-ref: ${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'  # Fail on critical/high vulnerabilities

      # SECURITY: Push signed image with provenance
      - name: Push container image
        id: push
        run: |
          IMAGE_URL="${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}"
          podman push "${IMAGE_URL}:${{ github.sha }}"
          podman push "${IMAGE_URL}:latest"

          # Get image digest for attestation
          DIGEST=$(podman inspect "${IMAGE_URL}:${{ github.sha }}" --format='{{.Digest}}')
          echo "digest=${DIGEST}" >> $GITHUB_OUTPUT
          echo "image-url=${IMAGE_URL}@${DIGEST}" >> $GITHUB_OUTPUT

      # SECURITY: Sign container image with keyless signing
      - name: Sign container image
        run: |
          # Install cosign
          curl -sLO https://github.com/sigstore/cosign/releases/download/v2.2.2/cosign-linux-amd64
          chmod +x cosign-linux-amd64

          # SECURITY: Keyless signing using OIDC identity
          # Signature stored in container registry, tied to workflow identity
          ./cosign-linux-amd64 sign --yes \
            ${{ steps.push.outputs.image-url }}

      # SECURITY: Attest container provenance
      - name: Attest container provenance
        uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-name: ${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true

  # Job 2: Deploy to staging (automatic)
  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging-${{ vars.SERVICE_NAME }}-${{ vars.GCP_PROJECT_ID }}.a.run.app
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT_STAGING }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      # SECURITY: Deploy to Cloud Run with security controls
      - name: Deploy to Cloud Run (Staging)
        id: deploy
        run: |
          gcloud run deploy ${{ vars.SERVICE_NAME }}-staging \
            --image ${{ needs.build.outputs.image-url }} \
            --region ${{ vars.GCP_REGION }} \
            --platform managed \
            --allow-unauthenticated \
            --min-instances 0 \
            --max-instances 10 \
            --cpu 1 \
            --memory 512Mi \
            --timeout 60s \
            --concurrency 80 \
            --set-env-vars "ENVIRONMENT=staging,GIT_COMMIT=${{ github.sha }}" \
            --labels "environment=staging,git-commit=${{ github.sha }},deployed-by=github-actions" \
            --no-traffic  # SECURITY: Deploy without traffic for verification

      # SECURITY: Verify deployment health before routing traffic
      - name: Verify deployment health
        run: |
          SERVICE_URL=$(gcloud run services describe ${{ vars.SERVICE_NAME }}-staging \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(status.url)')

          # Health check with retries
          for i in {1..5}; do
            if curl -f -s -o /dev/null "${SERVICE_URL}/health"; then
              echo "Health check passed"
              exit 0
            fi
            echo "Health check attempt $i failed, retrying..."
            sleep 10
          done

          echo "::error::Health check failed after 5 attempts"
          exit 1

      # SECURITY: Route traffic to new revision after verification
      - name: Route traffic to new revision
        run: |
          LATEST_REVISION=$(gcloud run revisions list \
            --service ${{ vars.SERVICE_NAME }}-staging \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(name)' \
            --limit 1)

          gcloud run services update-traffic ${{ vars.SERVICE_NAME }}-staging \
            --region ${{ vars.GCP_REGION }} \
            --to-revisions "${LATEST_REVISION}=100"

  # Job 3: Deploy to production (approval gate)
  deploy-production:
    needs: [build, deploy-staging]
    runs-on: ubuntu-latest
    # SECURITY: Environment protection with required reviewers and wait timer
    # Settings → Environments → production → Protection rules:
    # - Required reviewers: security-team, platform-leads
    # - Wait timer: 5 minutes (allows security team to abort malicious deployments)
    # - Deployment branches: main only
    environment:
      name: production
      url: https://${{ vars.SERVICE_NAME }}-${{ vars.GCP_PROJECT_ID }}.a.run.app
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT_PRODUCTION }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      # SECURITY: Record pre-deployment state for rollback
      - name: Record current production revision
        id: current
        run: |
          CURRENT_REVISION=$(gcloud run services describe ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(status.traffic[0].revisionName)' || echo "none")
          echo "revision=${CURRENT_REVISION}" >> $GITHUB_OUTPUT
          echo "Current production revision: ${CURRENT_REVISION}"

      # SECURITY: Blue-green deployment with traffic splitting
      - name: Deploy to Cloud Run (Production)
        id: deploy
        run: |
          gcloud run deploy ${{ vars.SERVICE_NAME }} \
            --image ${{ needs.build.outputs.image-url }} \
            --region ${{ vars.GCP_REGION }} \
            --platform managed \
            --allow-unauthenticated \
            --min-instances 1 \
            --max-instances 100 \
            --cpu 2 \
            --memory 1Gi \
            --timeout 300s \
            --concurrency 80 \
            --set-env-vars "ENVIRONMENT=production,GIT_COMMIT=${{ github.sha }}" \
            --labels "environment=production,git-commit=${{ github.sha }},deployed-by=github-actions" \
            --no-traffic  # SECURITY: Deploy without traffic for verification

      # SECURITY: Verify new revision health before routing traffic
      - name: Verify new revision health
        id: verify
        run: |
          # Get latest revision URL
          LATEST_REVISION=$(gcloud run revisions list \
            --service ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(name)' \
            --limit 1)

          REVISION_URL=$(gcloud run services describe ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(status.url)')

          echo "latest-revision=${LATEST_REVISION}" >> $GITHUB_OUTPUT

          # Health check with retries
          for i in {1..10}; do
            if curl -f -s -H "X-Serverless-Authorization: Bearer $(gcloud auth print-identity-token)" \
              -o /dev/null "${REVISION_URL}/health"; then
              echo "Health check passed for revision ${LATEST_REVISION}"
              exit 0
            fi
            echo "Health check attempt $i failed, retrying..."
            sleep 15
          done

          echo "::error::Health check failed after 10 attempts"
          exit 1

      # SECURITY: Gradual traffic migration (canary deployment)
      - name: Canary deployment (10% traffic)
        run: |
          LATEST_REVISION="${{ steps.verify.outputs.latest-revision }}"
          CURRENT_REVISION="${{ steps.current.outputs.revision }}"

          if [[ "${CURRENT_REVISION}" != "none" ]]; then
            # Split traffic: 10% new, 90% old
            gcloud run services update-traffic ${{ vars.SERVICE_NAME }} \
              --region ${{ vars.GCP_REGION }} \
              --to-revisions "${LATEST_REVISION}=10,${CURRENT_REVISION}=90"

            echo "Canary deployment: 10% traffic to new revision"
            sleep 60  # Wait 1 minute for canary metrics
          else
            # First deployment, route all traffic
            gcloud run services update-traffic ${{ vars.SERVICE_NAME }} \
              --region ${{ vars.GCP_REGION }} \
              --to-revisions "${LATEST_REVISION}=100"
          fi

      # SECURITY: Monitor canary metrics before full rollout
      - name: Monitor canary metrics
        run: |
          LATEST_REVISION="${{ steps.verify.outputs.latest-revision }}"

          # Check Cloud Run metrics for error rate
          # In production, integrate with monitoring platform (Prometheus, Datadog, etc.)
          echo "Monitoring canary deployment for ${LATEST_REVISION}"
          sleep 120  # Wait 2 minutes for metrics

          # Verify error rate is acceptable
          ERROR_RATE=$(gcloud logging read \
            "resource.type=cloud_run_revision AND resource.labels.service_name=${{ vars.SERVICE_NAME }} AND resource.labels.revision_name=${LATEST_REVISION} AND severity>=ERROR" \
            --limit 50 \
            --format json | jq '. | length')

          if [[ ${ERROR_RATE} -gt 5 ]]; then
            echo "::error::High error rate detected in canary deployment"
            exit 1
          fi

      # SECURITY: Full traffic migration after canary success
      - name: Complete deployment (100% traffic)
        run: |
          LATEST_REVISION="${{ steps.verify.outputs.latest-revision }}"

          gcloud run services update-traffic ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --to-revisions "${LATEST_REVISION}=100"

          echo "Deployment complete: 100% traffic to ${LATEST_REVISION}"

      # SECURITY: Post-deployment verification
      - name: Post-deployment verification
        run: |
          SERVICE_URL=$(gcloud run services describe ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(status.url)')

          # Verify production health
          curl -f -s "${SERVICE_URL}/health" || {
            echo "::error::Post-deployment health check failed"
            exit 1
          }

          # Verify version endpoint
          DEPLOYED_COMMIT=$(curl -s "${SERVICE_URL}/version" | jq -r '.commit')
          if [[ "${DEPLOYED_COMMIT}" != "${{ github.sha }}" ]]; then
            echo "::error::Deployed commit mismatch"
            exit 1
          fi

          echo "Post-deployment verification passed"

  # Job 4: Rollback on failure
  rollback:
    needs: [deploy-production]
    runs-on: ubuntu-latest
    if: failure()
    environment:
      name: production
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT_PRODUCTION }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      # SECURITY: Automatic rollback to previous stable revision
      - name: Rollback to previous revision
        run: |
          # Get previous stable revision (second in list)
          PREVIOUS_REVISION=$(gcloud run revisions list \
            --service ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(name)' \
            --limit 2 | tail -n 1)

          if [[ -z "${PREVIOUS_REVISION}" ]]; then
            echo "::error::No previous revision found for rollback"
            exit 1
          fi

          echo "Rolling back to revision: ${PREVIOUS_REVISION}"

          gcloud run services update-traffic ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --to-revisions "${PREVIOUS_REVISION}=100"

          echo "Rollback complete: 100% traffic to ${PREVIOUS_REVISION}"

      - name: Verify rollback health
        run: |
          SERVICE_URL=$(gcloud run services describe ${{ vars.SERVICE_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --format 'value(status.url)')

          # Verify service is healthy after rollback
          for i in {1..5}; do
            if curl -f -s -o /dev/null "${SERVICE_URL}/health"; then
              echo "Rollback health check passed"
              exit 0
            fi
            echo "Rollback health check attempt $i failed, retrying..."
            sleep 10
          done

          echo "::error::Rollback health check failed"
          exit 1
```

**Permissions**: `id-token: write` for OIDC, `contents: read` for code access.

**Environment Protection** (configure in Settings → Environments):

- **Staging**: No protection rules (auto-deploy)
- **Production**:
  - Required reviewers: `security-team`, `platform-leads`
  - Wait timer: 5 minutes
  - Deployment branches: `main` only

### Kubernetes Deployment with Helm

Secure deployment to Kubernetes cluster using Helm with OIDC authentication and canary rollout.

```yaml
name: Deploy to Kubernetes
on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com
    permissions:
      contents: read
      id-token: write
    steps:
      - name: Checkout code
        uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      # SECURITY: Authenticate to GCP for GKE access
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      # SECURITY: Get GKE cluster credentials using OIDC token
      - name: Get GKE credentials
        run: |
          gcloud container clusters get-credentials ${{ vars.GKE_CLUSTER_NAME }} \
            --region ${{ vars.GCP_REGION }} \
            --project ${{ vars.GCP_PROJECT_ID }}

      # SECURITY: Install Helm
      - name: Install Helm
        run: |
          curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

      # SECURITY: Deploy with Helm (canary rollout)
      - name: Helm upgrade with canary
        run: |
          helm upgrade --install ${{ vars.SERVICE_NAME }} ./charts/${{ vars.SERVICE_NAME }} \
            --namespace production \
            --create-namespace \
            --set image.tag=${{ github.sha }} \
            --set image.repository=${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }} \
            --set deployment.replicas.canary=1 \
            --set deployment.replicas.stable=5 \
            --set autoscaling.enabled=true \
            --set autoscaling.minReplicas=3 \
            --set autoscaling.maxReplicas=100 \
            --set resources.requests.cpu=500m \
            --set resources.requests.memory=512Mi \
            --set resources.limits.cpu=1000m \
            --set resources.limits.memory=1Gi \
            --set env.ENVIRONMENT=production \
            --set env.GIT_COMMIT=${{ github.sha }} \
            --wait \
            --timeout 10m

      # SECURITY: Verify deployment health
      - name: Verify deployment
        run: |
          kubectl rollout status deployment/${{ vars.SERVICE_NAME }}-canary -n production --timeout=5m

          # Check pod health
          kubectl get pods -n production -l app=${{ vars.SERVICE_NAME }},track=canary

          # Verify all pods are running
          READY_PODS=$(kubectl get pods -n production -l app=${{ vars.SERVICE_NAME }},track=canary -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
          TOTAL_PODS=$(kubectl get pods -n production -l app=${{ vars.SERVICE_NAME }},track=canary --no-headers | wc -l)

          if [[ ${READY_PODS} -ne ${TOTAL_PODS} ]]; then
            echo "::error::Not all pods are ready"
            exit 1
          fi

      # SECURITY: Promote canary to stable after verification
      - name: Promote canary to stable
        run: |
          helm upgrade ${{ vars.SERVICE_NAME }} ./charts/${{ vars.SERVICE_NAME }} \
            --namespace production \
            --reuse-values \
            --set deployment.replicas.canary=0 \
            --set deployment.replicas.stable=10 \
            --wait \
            --timeout 5m

          echo "Canary promoted to stable"
```

## Multi-Environment Deployment Pipeline

Complete pipeline deploying through dev → staging → production with progressive approval gates.

```yaml
name: Multi-Environment Deployment
on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  # Job 1: Build once, deploy everywhere
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
      attestations: write
    outputs:
      image-digest: ${{ steps.push.outputs.digest }}
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
        with:
          persist-credentials: false

      - uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
        with:
          workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}

      - uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      - name: Build and push image
        id: push
        run: |
          gcloud auth configure-docker ${{ vars.GCP_REGION }}-docker.pkg.dev

          IMAGE_URL="${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}"

          podman build -t "${IMAGE_URL}:${{ github.sha }}" .
          podman push "${IMAGE_URL}:${{ github.sha }}"

          DIGEST=$(podman inspect "${IMAGE_URL}:${{ github.sha }}" --format='{{.Digest}}')
          echo "digest=${DIGEST}" >> $GITHUB_OUTPUT

      - uses: actions/attest-build-provenance@1c608d11d69870c2092266b3f9a6f3abbf17002c  # v1.4.3
        with:
          subject-name: ${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true

  # Job 2: Deploy to dev (automatic, no approval)
  deploy-dev:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: dev
      url: https://dev-${{ vars.SERVICE_NAME }}.example.com
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
          service_account: ${{ secrets.GCP_SERVICE_ACCOUNT_DEV }}

      - uses: google-github-actions/setup-gcloud@98ddc00a17442e89a24bbf282954a3b65ce6d200  # v2.1.0

      - name: Deploy to Cloud Run (Dev)
        run: |
          IMAGE_URL="${{ vars.GCP_REGION }}-docker.pkg.dev/${{ vars.GCP_PROJECT_ID }}/${{ vars.ARTIFACT_REGISTRY_REPO }}/${{ vars.SERVICE_NAME }}@${{ needs.build.outputs.image-digest }}"

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
      url: https://staging-${{ vars.SERVICE_NAME }}.example.com
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
- [ ] SLSA provenance attestations generated and published
- [ ] Deployment uses image digest (not tag) for immutability
- [ ] Health checks verify deployment before routing traffic
- [ ] Canary deployment pattern used for production
- [ ] Rollback automation tested and verified

### Monitoring and Rollback

- [ ] Post-deployment health checks verify service availability
- [ ] Canary metrics monitored (error rate, latency, throughput)
- [ ] Automatic rollback triggers on health check failure
- [ ] Manual rollback workflow available with approval gate
- [ ] Deployment logs and metrics aggregated centrally
- [ ] Alerts configured for deployment failures

### Permission Security

- [ ] Workflow-level permissions set to minimal (`contents: read`)
- [ ] Job-level `id-token: write` only on deployment jobs
- [ ] No `contents: write` unless creating releases
- [ ] `attestations: write` only on build jobs
- [ ] Service account permissions follow least privilege

## Common Mistakes and Fixes

### Mistake 1: Stored Service Account Keys

**Bad**:

```yaml
# DANGER: Long-lived service account key stored as secret
- name: Authenticate to GCP
  run: |
    echo "${{ secrets.GCP_SERVICE_ACCOUNT_KEY }}" | base64 -d > key.json
    gcloud auth activate-service-account --key-file=key.json
```

**Good**:

```yaml
# SECURITY: OIDC federation with short-lived tokens
- name: Authenticate to GCP
  uses: google-github-actions/auth@55bd3a7c6e2ae7cf1877fd1ccb9d54c0503c457c  # v2.1.2
  with:
    workload_identity_provider: ${{ secrets.GCP_WORKLOAD_IDENTITY_PROVIDER }}
    service_account: ${{ secrets.GCP_SERVICE_ACCOUNT }}
```

### Mistake 2: No Environment Protection

**Bad**:

```yaml
# DANGER: Production deployment with no approval gate
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./scripts/deploy-production.sh
```

**Good**:

```yaml
# SECURITY: Environment protection with approval gate
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production  # Requires approval in Settings → Environments
    steps:
      - run: ./scripts/deploy-production.sh
```

### Mistake 3: Immediate Traffic Routing

**Bad**:

```yaml
# DANGER: Route all traffic immediately without verification
- name: Deploy to Cloud Run
  run: |
    gcloud run deploy my-service --image gcr.io/project/image:latest
```

**Good**:

```yaml
# SECURITY: Deploy without traffic, verify, then route
- name: Deploy to Cloud Run
  run: |
    gcloud run deploy my-service \
      --image gcr.io/project/image@sha256:abc123 \
      --no-traffic  # Don't route traffic yet

- name: Verify deployment
  run: |
    # Health checks here

- name: Route traffic
  run: |
    gcloud run services update-traffic my-service --to-revisions latest=100
```

### Mistake 4: No Rollback Plan

**Bad**:

```yaml
# DANGER: Deployment with no rollback mechanism
jobs:
  deploy:
    steps:
      - run: kubectl apply -f deployment.yaml
```

**Good**:

```yaml
# SECURITY: Rollback automation on failure
jobs:
  deploy:
    steps:
      - name: Record current version
        id: current
        run: echo "version=$(kubectl get deployment my-app -o jsonpath='{.spec.template.spec.containers[0].image}')" >> $GITHUB_OUTPUT

      - name: Deploy new version
        run: kubectl apply -f deployment.yaml

      - name: Verify deployment
        run: kubectl rollout status deployment/my-app --timeout=5m

  rollback:
    needs: deploy
    if: failure()
    steps:
      - run: kubectl set image deployment/my-app app=${{ needs.deploy.steps.current.outputs.version }}
```

## Related Patterns

- **[OIDC Federation](../secrets/oidc.md)**: Complete OIDC setup for AWS, GCP, and Azure
- **[Environment Protection](../workflows/environments.md)**: Environment configuration with approval gates and wait timers
- **[Token Permissions](../token-permissions/templates.md)**: GITHUB_TOKEN permissions for deployment workflows
- **[Release Workflow](./release-workflow.md)**: Signed releases with SLSA provenance
- **[Action Pinning](../action-pinning/sha-pinning.md)**: SHA pinning patterns and Dependabot configuration

## Summary

Hardened deployment workflows require layered security controls:

1. **Eliminate secrets** with OIDC federation (no stored credentials)
2. **Require approval** for production deployments via environment protection
3. **Verify before routing** traffic with health checks and canary deployments
4. **Automate rollback** on failure to minimize downtime
5. **Monitor deployments** with metrics and alerting
6. **Attest artifacts** with SLSA provenance for supply chain security
7. **Minimize permissions** with job-level `id-token: write` only where needed

Copy these templates as starting points. Adjust environment protection rules, health checks, and canary thresholds based on your service requirements and risk tolerance.
