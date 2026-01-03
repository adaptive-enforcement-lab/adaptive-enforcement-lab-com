---
title: Multi-Environment Deployment Pipeline
description: >-
  Coordinated deployment across multiple environments with gates and approval workflows
---

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
