---
title: Service Account Binding
description: >-
  Create Kubernetes ServiceAccounts and GCP service accounts. Configure IAM bindings for Workload Identity with least-privilege access to GCP resources.
---

# Service Account Binding

Link Kubernetes ServiceAccounts to GCP service accounts through IAM bindings. This establishes the trust relationship for Workload Identity.

## Configure Kubernetes ServiceAccount

Create a Kubernetes ServiceAccount in your namespace:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: app-gcp@PROJECT_ID.iam.gserviceaccount.com
```

The annotation links the Kubernetes ServiceAccount to a GCP service account.

!!! note "Annotation Key"

    The annotation key is `iam.gke.io/gcp-service-account`. This tells GKE which GCP service account the pod should impersonate.

## Create GCP Service Account

```bash
# Create service account in GCP
gcloud iam service-accounts create app-gcp \
  --display-name "App workload identity"

# Grant it the necessary role(s)
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

This service account holds the actual permissions. The Kubernetes ServiceAccount only acts **as** this account.

!!! danger "Least Privilege"

    Grant only the permissions the workload needs. Avoid `roles/editor` or `roles/owner`.

## Bind Kubernetes ServiceAccount to GCP Service Account

```bash
# Allow the Kubernetes ServiceAccount to impersonate the GCP service account
gcloud iam service-accounts add-iam-policy-binding \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[production/app-sa]"
```

Format: `serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/KSA_NAME]`

This is the crucial binding. It declares that the Kubernetes ServiceAccount `production/app-sa` can impersonate `app-gcp@PROJECT_ID.iam.gserviceaccount.com`.

!!! warning "Binding Format"

    The member format is critical:

    - `serviceAccount:` prefix
    - `PROJECT_ID.svc.id.goog` (workload pool)
    - `[NAMESPACE/KSA_NAME]` (Kubernetes namespace and ServiceAccount name)

## Terraform Configuration

For infrastructure-as-code:

```hcl
# Create GCP service account
resource "google_service_account" "app" {
  account_id   = "app-gcp"
  display_name = "App workload identity"
  project      = var.project_id
}

# Grant permissions to service account
resource "google_project_iam_member" "app_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# Allow Kubernetes ServiceAccount to impersonate GCP service account
resource "google_service_account_iam_member" "app_workload_identity_user" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[production/app-sa]"
}

# Output the GCP service account email for Kubernetes annotation
output "gcp_service_account_email" {
  value = google_service_account.app.email
}
```

Use this Terraform to create the GCP side. Then reference the output in your Kubernetes manifests:

```bash
# Get the service account email from Terraform
export GCP_SA_EMAIL=$(terraform output -raw gcp_service_account_email)

# Create Kubernetes ServiceAccount with annotation
kubectl create serviceaccount app-sa -n production
kubectl annotate serviceaccount app-sa -n production \
  "iam.gke.io/gcp-service-account=${GCP_SA_EMAIL}"
```

## Multiple Namespace Bindings

One GCP service account can be used by multiple Kubernetes namespaces:

```bash
# Bind to namespace 'production'
gcloud iam service-accounts add-iam-policy-binding \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[production/app-sa]"

# Bind to namespace 'staging'
gcloud iam service-accounts add-iam-policy-binding \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[staging/app-sa]"
```

!!! warning "Shared Permissions"

    All namespaces using the same GCP service account share its permissions. Consider separate service accounts per environment.

## Resource-Level IAM

Grant access to specific resources instead of project-wide:

```bash
# Grant access only to a specific GCS bucket
gcloud storage buckets add-iam-policy-binding gs://sensitive-data \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Grant access to a specific BigQuery dataset
bq add-iam-policy-binding \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataViewer" \
  PROJECT_ID:dataset_name

# Grant access to specific Secret Manager secrets
gcloud secrets add-iam-policy-binding secret-name \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

## Cross-Project Bindings

Allow service accounts from one project to access resources in another:

```bash
# In PROJECT_A: Create service account
gcloud iam service-accounts create app-a \
  --project PROJECT_A \
  --display-name "App in PROJECT_A"

# In PROJECT_B: Grant permissions
gcloud projects add-iam-policy-binding PROJECT_B \
  --member="serviceAccount:app-a@PROJECT_A.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# In PROJECT_A: Bind to Kubernetes ServiceAccount
gcloud iam service-accounts add-iam-policy-binding \
  app-a@PROJECT_A.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_A.svc.id.goog[production/app-sa]"
```

## Service Account Impersonation

One service account can impersonate another:

```bash
# SERVICE_ACCOUNT_A impersonates SERVICE_ACCOUNT_B
gcloud iam service-accounts add-iam-policy-binding \
  service-account-b@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.serviceAccountTokenCreator" \
  --member="serviceAccount:service-account-a@PROJECT_ID.iam.gserviceaccount.com"
```

Use this for temporary privilege escalation or cross-project access.

## Verification

```bash
# 1. Verify ServiceAccount is annotated
kubectl get serviceaccount app-sa -n production -o yaml \
  | grep gcp-service-account

# 2. Verify IAM binding exists
gcloud iam service-accounts get-iam-policy \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com

# Expected output includes:
# - role: roles/iam.workloadIdentityUser
#   members:
#   - serviceAccount:PROJECT_ID.svc.id.goog[production/app-sa]

# 3. Test from pod
kubectl run -it --rm debug \
  --image=google/cloud-sdk:slim \
  --serviceaccount=app-sa \
  --namespace=production \
  -- gcloud auth list

# Expected output: app-gcp@PROJECT_ID.iam.gserviceaccount.com
```

!!! success "Expected Output"

    The `gcloud auth list` command should show the GCP service account email, not the Compute Engine default service account.

## Audit IAM Bindings

```bash
# List all Workload Identity bindings for a service account
gcloud iam service-accounts get-iam-policy \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --filter="bindings.role:roles/iam.workloadIdentityUser" \
  --format="table(bindings.role, bindings.members)"

# List all service accounts with Workload Identity bindings
gcloud iam service-accounts list \
  --project=PROJECT_ID \
  --format="table(email, displayName)" | while read sa; do
  echo "=== $sa ==="
  gcloud iam service-accounts get-iam-policy "$sa" \
    --filter="bindings.role:roles/iam.workloadIdentityUser" \
    --format="yaml"
done
```

## Remove Bindings

```bash
# Remove Workload Identity binding
gcloud iam service-accounts remove-iam-policy-binding \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[production/app-sa]"

# Delete GCP service account (revokes all access immediately)
gcloud iam service-accounts delete app-gcp@PROJECT_ID.iam.gserviceaccount.com
```

## Related Configuration

- **[Cluster Configuration](cluster-configuration.md)** - Enable Workload Identity on GKE clusters
- **[Pod Configuration](pod-configuration.md)** - Deploy workloads and common access patterns
- **[Troubleshooting](troubleshooting.md)** - Debug IAM binding issues

## References

- [IAM Service Accounts](https://cloud.google.com/iam/docs/service-accounts)
- [Workload Identity Bindings](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_account_iam)
