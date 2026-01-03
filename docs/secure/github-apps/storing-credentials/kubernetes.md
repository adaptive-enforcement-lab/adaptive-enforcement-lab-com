---
title: Kubernetes Secrets Integration
description: >-
  Integrate GitHub App credentials with Kubernetes using External Secrets Operator, Sealed Secrets, and native Kubernetes secrets.
---

# Kubernetes Secrets Integration

## External Secrets Operator (Recommended)

Use External Secrets Operator to sync secrets from external secret managers to Kubernetes.

### AWS Secrets Manager Integration

**1. Store credentials in AWS Secrets Manager**:

```bash
aws secretsmanager create-secret \
  --name github-app-credentials \
  --secret-string '{
    "app_id": "123456",
    "private_key": "-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
  }'
```

**2. Create SecretStore**:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secretsmanager
  namespace: automation
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

**3. Create ExternalSecret**:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: github-app-credentials
  namespace: automation
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: SecretStore
  target:
    name: github-app-credentials
    creationPolicy: Owner
  data:
    - secretKey: app-id
      remoteRef:
        key: github-app-credentials
        property: app_id
    - secretKey: private-key
      remoteRef:
        key: github-app-credentials
        property: private_key
```

**4. Use in Pod**:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: github-automation
  namespace: automation
spec:
  containers:
    - name: automation
      image: ghcr.io/my-org/automation:latest
      env:
        - name: GITHUB_APP_ID
          valueFrom:
            secretKeyRef:
              name: github-app-credentials
              key: app-id
        - name: GITHUB_APP_PRIVATE_KEY
          valueFrom:
            secretKeyRef:
              name: github-app-credentials
              key: private-key
```

### HashiCorp Vault Integration

**1. Store credentials in Vault**:

```bash
vault kv put secret/github-app \
  app_id=123456 \
  private_key=@github-app.pem
```

**2. Create SecretStore**:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: automation
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: external-secrets-sa
```

**3. Create ExternalSecret**:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: github-app-credentials
  namespace: automation
spec:
  refreshInterval: 15m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: github-app-credentials
    creationPolicy: Owner
  data:
    - secretKey: app-id
      remoteRef:
        key: github-app
        property: app_id
    - secretKey: private-key
      remoteRef:
        key: github-app
        property: private_key
```

!!! success "External Secrets Advantages"

    - **Centralized management** - Single source of truth in external vault
    - **Automatic rotation** - Secrets sync automatically on refresh interval
    - **Audit trail** - Vault access logs track secret usage
    - **Multi-cluster** - Share secrets across clusters
    - **Policy enforcement** - Vault policies control access

### Google Secret Manager Integration

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: gcpsm-secretstore
  namespace: automation
spec:
  provider:
    gcpsm:
      projectID: "my-project"
      auth:
        workloadIdentity:
          clusterLocation: us-central1
          clusterName: production-cluster
          serviceAccountRef:
            name: external-secrets-sa

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: github-app-credentials
  namespace: automation
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcpsm-secretstore
    kind: SecretStore
  target:
    name: github-app-credentials
  data:
    - secretKey: app-id
      remoteRef:
        key: github-app-id
    - secretKey: private-key
      remoteRef:
        key: github-app-private-key
```

### Sealed Secrets (GitOps Alternative)

For GitOps workflows where secrets must be stored in Git.

**1. Install Sealed Secrets controller**:

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

**2. Seal the secret**:

```bash
# Create secret
kubectl create secret generic github-app-credentials \
  --from-literal=app-id=123456 \
  --from-file=private-key=github-app.pem \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > sealed-secret.yaml
```

**3. Commit sealed secret to Git**:

```yaml
# sealed-secret.yaml (safe to commit)
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: github-app-credentials
  namespace: automation
spec:
  encryptedData:
    app-id: AgBL8f7v... (encrypted)
    private-key: AgCq9h3x... (encrypted)
```

**4. Deploy via GitOps**:

```bash
kubectl apply -f sealed-secret.yaml
# Controller decrypts and creates Secret automatically
```

!!! warning "Sealed Secrets Rotation"

    Rotating sealed secrets requires re-sealing with `kubeseal`. Automate this process or use External Secrets for automatic rotation.

### Native Kubernetes Secrets (Not Recommended)

Only for development or when external secret managers aren't available.

```bash
kubectl create secret generic github-app-credentials \
  --from-literal=app-id=123456 \
  --from-file=private-key=github-app.pem \
  -n automation
```

!!! danger "Native Secrets Limitations"

    - Base64 encoded, not encrypted at rest (without additional configuration)
    - No automatic rotation
    - No audit trail
    - Difficult to manage across multiple clusters
    - Secrets stored in etcd (secure your etcd cluster)
