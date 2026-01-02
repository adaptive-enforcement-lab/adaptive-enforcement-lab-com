---
title: Troubleshooting
description: Debug Workload Identity authentication failures, token expiration issues, IAM binding errors, and metadata server connectivity using diagnostic command tools.
---

# Troubleshooting Workload Identity

Common issues when implementing Workload Identity and how to fix them.

## Error: "Unable to generate access token"

**Symptom**: Pod cannot access Cloud APIs. Logs show credential errors.

**Cause**: The IAM binding is missing or misconfigured.

**Fix**:

```bash
# Verify the binding exists
gcloud iam service-accounts get-iam-policy \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com

# If missing, add it
gcloud iam service-accounts add-iam-policy-binding \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[production/app-sa]"

# Restart Pods to pick up the change
kubectl rollout restart deployment/app -n production
```

!!! warning "Binding Format"

    Verify the member format is exact: `serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/SA_NAME]`

## Error: "Insufficient permissions"

**Symptom**: Pod can authenticate but lacks permissions for specific APIs.

**Cause**: The GCP service account doesn't have the required role.

**Fix**:

```bash
# Verify current roles
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:app-gcp@*"

# Grant the required role
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.admin"  # Or whatever role is needed

# Restart Pods
kubectl rollout restart deployment/app -n production
```

## Error: "Could not open /var/run/secrets/workload-identity/token"

**Symptom**: Token file doesn't exist in the Pod.

**Cause**: Workload Identity not enabled on the cluster, or Pod not using an annotated ServiceAccount.

**Fix**:

```bash
# Verify cluster has Workload Identity enabled
gcloud container clusters describe my-cluster --zone us-central1-a \
  | grep workloadPool

# If missing, enable it
gcloud container clusters update my-cluster \
  --workload-pool=PROJECT_ID.svc.id.goog \
  --zone us-central1-a

# Verify ServiceAccount is annotated
kubectl get serviceaccount app-sa -n production -o yaml \
  | grep gcp-service-account

# If missing, annotate it
kubectl annotate serviceaccount app-sa \
  -n production \
  iam.gke.io/gcp-service-account=app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --overwrite

# Restart Pods
kubectl rollout restart deployment/app -n production
```

## Error: "Metadata server connection timeout"

**Symptom**: Pod timeout when calling metadata server.

**Cause**: Usually a network issue or misconfigured firewall.

**Fix**:

```bash
# Verify Pod can reach metadata server
kubectl exec -it deployment/app -n production -- \
  curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity

# Check Pod network connectivity
kubectl exec -it deployment/app -n production -- nslookup metadata.google.internal

# Verify firewall rules don't block metadata server
gcloud compute firewall-rules list --filter="direction:EGRESS" --format=json | jq '.[] | {name, sourceRanges, destinationRanges}'
```

## Debugging: Inspect the Token

```bash
# Get the token from a running Pod
kubectl exec -it deployment/app -n production -- \
  cat /var/run/secrets/tokens/gcp-ksa > token.txt

# Decode the JWT (format: header.payload.signature)
jq -R "split(\".\") | .[1] | @base64d | fromjson" < token.txt

# Expected payload:
# {
#   "aud": ["https://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/providers/..."],
#   "exp": 1234567890,
#   "iat": 1234567800,
#   "iss": "https://kubernetes.default.svc.cluster.local",
#   "kubernetes.io": { "namespace": "production", "pod": { "name": "app-xxx", "uid": "..." }, "serviceaccount": { "name": "app-sa", "uid": "..." } },
#   "sub": "system:serviceaccount:production:app-sa"
# }
```

Verify:

- `kubernetes.io.namespace` is correct
- `kubernetes.io.serviceaccount.name` is correct
- Token is not expired (compare `exp` to current Unix time)

!!! tip "Token Expiry"

    Tokens expire after 1 hour. Applications should handle token refresh automatically.

## Token Not Rotating

**Symptom**: Pod uses same token for hours.

**Cause**: Token file not being read by application.

**Fix**: Ensure your application reads the token from disk on every API call, not just once at startup.

```python
# BAD: Read token once at startup
token = open('/var/run/secrets/tokens/gcp-ksa').read()
credentials = create_credentials_from_token(token)  # Token will expire!

# GOOD: Let Google client library handle it
from google.auth.transport.requests import Request
from google.auth import default

credentials, _ = default()  # Library reads and rotates token automatically
```

## Cross-Project Access Not Working

**Symptom**: Pod can access resources in its own project but not others.

**Cause**: Missing impersonation binding in the target project.

**Fix**:

```bash
# In PROJECT_B, verify the binding
gcloud iam service-accounts get-iam-policy \
  external-reader@PROJECT_B.iam.gserviceaccount.com \
  --filter="bindings.role:iam.serviceAccountUser" \
  --format=json

# If missing, add it from PROJECT_A
gcloud iam service-accounts add-iam-policy-binding \
  external-reader@PROJECT_B.iam.gserviceaccount.com \
  --role="roles/iam.serviceAccountUser" \
  --member="serviceAccount:app-gcp@PROJECT_A.iam.gserviceaccount.com"
```

## Diagnostic Commands

```bash
#!/bin/bash
# Comprehensive Workload Identity diagnostics

echo "=== Cluster Configuration ==="
gcloud container clusters describe my-cluster --zone us-central1-a \
  --format="value(workloadIdentityConfig.workloadPool)"

echo ""
echo "=== ServiceAccount Annotation ==="
kubectl get serviceaccount app-sa -n production -o jsonpath='{.metadata.annotations}'

echo ""
echo "=== IAM Binding ==="
gcloud iam service-accounts get-iam-policy \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --format=json | jq '.bindings[] | select(.role == "roles/iam.workloadIdentityUser")'

echo ""
echo "=== Pod Configuration ==="
kubectl get deployment app -n production -o jsonpath='{.spec.template.spec.serviceAccountName}'

echo ""
echo "=== Token Verification ==="
kubectl exec deployment/app -n production -- ls -la /var/run/secrets/tokens/
```

!!! success "All Checks Pass"

    If all commands return expected values, Workload Identity is correctly configured.

## Security Best Practices

### 1. Principle of Least Privilege

Don't grant `Editor` or `Owner` roles. Grant specific roles:

```bash
# BAD
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# GOOD: Grant only what's needed
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudkms.cryptoKeyDecrypter"
```

### 2. Resource-Level IAM

Restrict access to specific resources, not entire services:

```bash
# Grant access only to a specific GCS bucket
gcloud storage buckets add-iam-policy-binding gs://sensitive-data \
  --member="serviceAccount:app-gcp@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"
```

### 3. Monitor Workload Identity Usage

Log all authentication attempts:

```bash
# Enable audit logging for Workload Identity
gcloud iam service-accounts get-iam-policy \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com

# Query Cloud Audit Logs
gcloud logging read \
  "protoPayload.methodName=GenerateAccessToken" \
  --limit 50 \
  --format json
```

### 4. Rotate Service Accounts (Not Keys)

With Workload Identity, you don't rotate keys. If you need to revoke access, delete the service account:

```bash
# Revoke all access immediately
gcloud iam service-accounts disable app-gcp@PROJECT_ID.iam.gserviceaccount.com

# Create a new service account
gcloud iam service-accounts create app-gcp-v2 \
  --display-name "App workload identity (v2)"

# Grant permissions to the new account
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:app-gcp-v2@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# Update the Workload Identity binding to use the new account
gcloud iam service-accounts add-iam-policy-binding \
  app-gcp-v2@PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:PROJECT_ID.svc.id.goog[production/app-sa]"

# Update Kubernetes ServiceAccount annotation
kubectl patch serviceaccount app-sa -n production -p \
  "{\"metadata\":{\"annotations\":{\"iam.gke.io/gcp-service-account\":\"app-gcp-v2@PROJECT_ID.iam.gserviceaccount.com\"}}}"

# Restart Pods
kubectl rollout restart deployment/app -n production

# Delete the old service account
gcloud iam service-accounts delete app-gcp@PROJECT_ID.iam.gserviceaccount.com
```

## Related Configuration

- **[Cluster Configuration](cluster-configuration.md)** - Enable Workload Identity on GKE clusters and node pools
- **[Service Account Binding](service-account-binding.md)** - Create service accounts and configure IAM bindings
- **[Pod Configuration](pod-configuration.md)** - Deploy workloads and common access patterns
- **[Migration Guide](migration-guide.md)** - Migrate from service account keys
- **[GKE Hardening](../gke-hardening/index.md)** - Comprehensive security configuration

## References

- [Troubleshooting Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#troubleshooting)
- [Cloud Audit Logs](https://cloud.google.com/logging/docs/audit)
- [IAM Best Practices](https://cloud.google.com/iam/docs/using-iam-securely)
