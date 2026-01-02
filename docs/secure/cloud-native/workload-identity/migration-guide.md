---
title: Migration Guide
description: Migrate from static service account keys to Workload Identity with zero downtime using parallel pod deployment and gradual production traffic shifting patterns.
---

# Migration from Service Account Keys

Service account keys are **static credentials** that never expire, frequently get stolen, and live in files forever.

## Before: Using Keys

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: app-sa-key
  namespace: production
type: Opaque
stringData:
  key.json: |
    {
      "type": "service_account",
      "project_id": "PROJECT_ID",
      "private_key_id": "key-id",
      "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...",
      "client_email": "app-gcp@PROJECT_ID.iam.gserviceaccount.com"
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: production
spec:
  template:
    spec:
      containers:
      - name: app
        image: gcr.io/PROJECT_ID/app:v1.0.0
        env:
        - name: GOOGLE_APPLICATION_CREDENTIALS
          value: /var/run/secrets/app-sa-key/key.json
        volumeMounts:
        - name: app-sa-key
          mountPath: /var/run/secrets/app-sa-key
          readOnly: true
      volumes:
      - name: app-sa-key
        secret:
          secretName: app-sa-key
```

The private key is a static secret in Kubernetes. If anyone gets the key file, they have permanent access to your resources.

!!! danger "Key Exposure"

    Service account keys never expire. If leaked, they provide indefinite access until manually revoked.

## After: Using Workload Identity

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: app-gcp@PROJECT_ID.iam.gserviceaccount.com
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: production
spec:
  template:
    spec:
      serviceAccountName: app-sa
      containers:
      - name: app
        image: gcr.io/PROJECT_ID/app:v1.0.0
```

No secret key. No static credentials. The token is short-lived (1 hour) and automatically rotated.

## Zero-Downtime Migration Steps

### 1. Deploy both in parallel

Create new Pods with Workload Identity while keeping old Pods with keys:

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-sa-new
  namespace: production
  annotations:
    iam.gke.io/gcp-service-account: app-gcp@PROJECT_ID.iam.gserviceaccount.com
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-new
  namespace: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app
      version: new
  template:
    metadata:
      labels:
        app: app
        version: new
    spec:
      serviceAccountName: app-sa-new
      containers:
      - name: app
        image: gcr.io/PROJECT_ID/app:v1.0.0
```

Traffic routes to both old and new Pods. Monitor the new Pods for auth errors.

### 2. Verify authentication

```bash
# Check logs in new Pod
kubectl logs -f deployment/app-new -n production

# Validate Cloud API calls are succeeding
kubectl exec -it deployment/app-new -n production -- \
  gcloud storage ls gs://my-bucket
```

### 3. Gradually shift traffic

Update the original Deployment to use Workload Identity:

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
      serviceAccountName: app-sa-new  # Switch to new SA
      containers:
      - name: app
        image: gcr.io/PROJECT_ID/app:v1.0.0
```

### 4. Delete old Pods with keys

```bash
# Scale down old Deployment
kubectl delete deployment app-old -n production

# Delete the secret with the key
kubectl delete secret app-sa-key -n production
```

### 5. Audit the change

```bash
# Verify no Pods are using the old service account
kubectl get pods -n production -o jsonpath='{.items[*].spec.serviceAccountName}' | tr ' ' '\n' | sort | uniq

# Verify no secrets contain private keys
kubectl get secrets -n production -o jsonpath='{.items[*].data.key\.json}' | wc -c
```

!!! success "Migration Complete"

    Zero service account keys in the cluster. All authentication uses short-lived tokens.

## Application Code Changes

Most Google Cloud client libraries automatically detect and use Workload Identity. No code changes required.

### Python

```python
# Before: Explicit key file
from google.cloud import storage
import os

os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = '/var/run/secrets/app-sa-key/key.json'
client = storage.Client()

# After: Automatic credential discovery
from google.cloud import storage

client = storage.Client()  # Credentials auto-detected
```

### Go

```go
// Before: Explicit key file
import (
    "context"
    "cloud.google.com/go/storage"
    "google.golang.org/api/option"
)

ctx := context.Background()
client, _ := storage.NewClient(ctx, option.WithCredentialsFile("/var/run/secrets/app-sa-key/key.json"))

// After: Automatic credential discovery
import (
    "context"
    "cloud.google.com/go/storage"
)

ctx := context.Background()
client, _ := storage.NewClient(ctx)  // Credentials auto-detected
```

### Java

```java
// Before: Explicit key file
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import com.google.auth.oauth2.ServiceAccountCredentials;

ServiceAccountCredentials credentials = ServiceAccountCredentials.fromStream(
    new FileInputStream("/var/run/secrets/app-sa-key/key.json"));

Storage storage = StorageOptions.newBuilder()
    .setCredentials(credentials)
    .build()
    .getService();

// After: Automatic credential discovery
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

Storage storage = StorageOptions.getDefaultInstance().getService();
```

### Node.js

```javascript
// Before: Explicit key file
const { Storage } = require('@google-cloud/storage');

const storage = new Storage({
  keyFilename: '/var/run/secrets/app-sa-key/key.json'
});

// After: Automatic credential discovery
const { Storage } = require('@google-cloud/storage');

const storage = new Storage();  // Credentials auto-detected
```

## Common Migration Issues

### Issue: Application still reads GOOGLE_APPLICATION_CREDENTIALS

**Fix**: Remove the environment variable from your Deployment:

```yaml
# Remove this
env:
- name: GOOGLE_APPLICATION_CREDENTIALS
  value: /var/run/secrets/app-sa-key/key.json
```

### Issue: Custom credential loading logic

**Fix**: Replace custom logic with library defaults:

```python
# Remove custom credential logic
# credentials = service_account.Credentials.from_service_account_file('/path/to/key.json')
# client = storage.Client(credentials=credentials)

# Use library defaults
from google.cloud import storage
client = storage.Client()  # Library handles credentials
```

## Verification

After migration:

```bash
# 1. No service account keys in cluster
kubectl get secrets -n production -o json | jq '.items[] | select(.data."key.json" != null)'

# 2. All pods use annotated ServiceAccounts
kubectl get pods -n production -o json | jq '.items[] | {name: .metadata.name, sa: .spec.serviceAccountName}'

# 3. Verify authentication works
kubectl exec -it deployment/app -n production -- gcloud auth list
```

## Related Configuration

- **[Pod Configuration](pod-configuration.md)** - Deploy workloads and common access patterns
- **[Service Account Binding](service-account-binding.md)** - Create service accounts and IAM bindings
- **[Troubleshooting](troubleshooting.md)** - Debug auth failures and token issues

## References

- [Migration Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#migrate_applications_to)
- [Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
- [Best Practices](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#best_practices)
