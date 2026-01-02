---
title: Pod Configuration
description: >-
  Deploy Kubernetes workloads with Workload Identity. Common GCP service access patterns for GCS, Firestore, BigQuery, Secret Manager, and Pub/Sub integration.
---

# Pod Configuration

Configure pods to use Workload Identity and integrate with GCP services. This guide covers deployment patterns and common access scenarios.

## Deploy Your Workload

Deploy a Pod with the annotated ServiceAccount:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
  template:
    metadata:
      labels:
        app: app
    spec:
      serviceAccountName: app-sa
      containers:
      - name: app
        image: gcr.io/PROJECT_ID/app:v1.0.0
```

!!! tip "GKE Default Behavior"

    On GKE with Workload Identity enabled, Kubernetes automatically injects the token volume into all Pods using an annotated ServiceAccount. You typically don't need to specify it explicitly.

## Common Patterns

### GCS (Google Cloud Storage) Access

```python
# Python example
from google.cloud import storage

# Credentials loaded automatically from token
storage_client = storage.Client(project='PROJECT_ID')
bucket = storage_client.bucket('my-bucket')
blob = bucket.blob('data.txt')
blob.download_to_filename('data.txt')
```

The SDK reads the token from the projected volume and uses it to authenticate.

### Firestore Database Access

```python
# Python example
from google.cloud import firestore

# Credentials loaded automatically
db = firestore.Client(project='PROJECT_ID')
docs = db.collection('users').where('status', '==', 'active').stream()

for doc in docs:
    print(doc.to_dict())
```

All Google Cloud client libraries support automatic credential discovery.

### Cloud API Calls (Direct HTTP)

```bash
#!/bin/bash
# Bash example: Call Cloud API directly

# Get token from metadata server
TOKEN=$(curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
  | jq -r .access_token)

# Call Cloud API
curl -H "Authorization: Bearer $TOKEN" \
  https://compute.googleapis.com/compute/v1/projects/PROJECT_ID/zones/us-central1-a/instances
```

Direct HTTP requests include the token in the `Authorization` header.

### Cross-Project Access

Your app may need to access resources in a different GCP project.

```bash
# Create service account in PROJECT_B
gcloud iam service-accounts create external-reader \
  --project PROJECT_B \
  --display-name "External reader for PROJECT_A"

# Grant permissions in PROJECT_B
gcloud projects add-iam-policy-binding PROJECT_B \
  --member="serviceAccount:external-reader@PROJECT_B.iam.gserviceaccount.com" \
  --role="roles/storage.objectViewer"

# In PROJECT_A, create a service account for your app
gcloud iam service-accounts create app-gcp \
  --project PROJECT_A \
  --display-name "App in PROJECT_A"

# Grant PROJECT_A service account permission to impersonate PROJECT_B service account
gcloud iam service-accounts add-iam-policy-binding \
  external-reader@PROJECT_B.iam.gserviceaccount.com \
  --role="roles/iam.serviceAccountUser" \
  --member="serviceAccount:app-gcp@PROJECT_A.iam.gserviceaccount.com"
```

Now your app running in PROJECT_A can impersonate the service account in PROJECT_B and access its resources.

### Secret Manager Access

```python
# Python example
from google.cloud import secretmanager

client = secretmanager.SecretManagerServiceClient()

# Access secret (credentials automatic)
secret_name = f"projects/PROJECT_ID/secrets/api-key/versions/latest"
response = client.access_secret_version(request={"name": secret_name})
api_key = response.payload.data.decode('UTF-8')
```

Combine Workload Identity with Secret Manager for encrypted credential storage.

### BigQuery Data Access

```python
# Python example
from google.cloud import bigquery

client = bigquery.Client(project='PROJECT_ID')

# Run query (credentials automatic)
query = """
    SELECT COUNT(*) as count FROM `PROJECT_ID.dataset.table`
"""
results = client.query(query).result()
for row in results:
    print(f"Count: {row['count']}")
```

Client libraries automatically use the token.

### Cloud Pub/Sub Publishing

```python
# Python example
from google.cloud import pubsub_v1

publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path('PROJECT_ID', 'my-topic')

# Publish message (credentials automatic)
data = b'Hello, World!'
message_id = publisher.publish(topic_path, data).result()
print(f"Published message ID: {message_id}")
```

All async operations use the token automatically.

## Validation Commands

After deployment, verify everything is working:

```bash
# 1. Verify ServiceAccount is annotated
kubectl get serviceaccount app-sa -n production -o yaml | grep gcp-service-account

# 2. Verify IAM binding exists
gcloud iam service-accounts get-iam-policy \
  app-gcp@PROJECT_ID.iam.gserviceaccount.com \
  --format='table(bindings[].role, bindings[].members[])'

# 3. Test Cloud API access from Pod
kubectl run -it --rm debug \
  --image=google/cloud-sdk:slim \
  --serviceaccount=app-sa \
  --namespace=production \
  -- gcloud storage ls gs://my-bucket

# 4. Verify token is being injected
kubectl exec -it deployment/app -n production -- \
  ls -la /var/run/secrets/tokens/

# 5. Decode the token and verify audience
kubectl exec -it deployment/app -n production -- \
  bash -c 'cat /var/run/secrets/tokens/gcp-ksa | head -c 100'
```

## Related Configuration

- **[Service Account Binding](service-account-binding.md)** - Create service accounts and IAM bindings
- **[Migration Guide](migration-guide.md)** - Migrate from service account keys
- **[Troubleshooting](troubleshooting.md)** - Debug auth failures, token issues, permissions
- **[GKE Hardening](../gke-hardening/index.md)** - Comprehensive security configuration

## References

- [Using Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [Google Cloud Client Libraries](https://cloud.google.com/apis/docs/cloud-client-libraries)
- [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
