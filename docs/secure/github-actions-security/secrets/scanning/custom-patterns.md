---
title: Custom Secret Patterns
description: >-
  Create custom secret scanning patterns with regex for organization-specific credentials, API keys, database connection strings, and internal service tokens
---

!!! tip "Define Organization-Specific Patterns"

    GitHub detects common cloud providers automatically, but organization-specific credentials require custom patterns. Define regex patterns for internal API keys, database connection strings, and proprietary service tokens.

Follow this runbook when secret scanning detects a credential.

## Step 1: Verify the Alert

**Check if secret is real**:

- Navigate to alert in `Security → Secret scanning alerts`
- Review detected secret value and location
- Confirm pattern matches actual credential format
- Check if secret is active or already revoked

**False Positive Indicators**:

- Example/placeholder values in documentation
- Test credentials clearly marked as fake
- Random strings that match pattern coincidentally
- Encrypted/hashed values misidentified as plaintext

**Action**:

- Real secret: Proceed to Step 2
- False positive: Dismiss alert with reason

## Response Workflow

### Step 2: Classify Severity

**Critical (Production Credential)**:

- Production cloud credentials (AWS, GCP, Azure)
- Production database passwords
- Production API keys with write access
- Payment gateway credentials
- Code signing certificates

**High (Production Read-Only)**:

- Production API keys with read-only access
- Monitoring service tokens
- Log aggregation credentials

**Medium (Non-Production)**:

- Staging/dev environment credentials
- Test account tokens
- Internal tool API keys

**Low (Expired/Revoked)**:

- Credentials already rotated
- Test secrets with no real access
- Expired certificates

### Step 3: Revoke the Credential

**Immediate Revocation (Critical)**:

```bash
#!/bin/bash
# emergency-revoke.sh
# Revoke compromised credential immediately

SECRET_TYPE="$1"  # e.g., "gcp-service-account"
SECRET_ID="$2"    # e.g., "sa-deployer@project.iam"

case "$SECRET_TYPE" in
  "gcp-service-account")
    # Revoke GCP service account key
    gcloud iam service-accounts keys delete "$SECRET_ID" \
      --iam-account="deployer@project.iam.gserviceaccount.com" \
      --quiet
    ;;

  "github-token")
    # Revoke GitHub personal access token via API
    gh api --method DELETE "/applications/${CLIENT_ID}/token" \
      -f access_token="${SECRET_ID}"
    ;;

  "api-key")
    # Revoke internal API key (org-specific)
    curl -X DELETE "https://api.internal/keys/${SECRET_ID}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}"
    ;;

  *)
    echo "Unknown secret type: ${SECRET_TYPE}"
    exit 1
    ;;
esac

echo "✓ Credential ${SECRET_ID} revoked"
```

**Verify Revocation**:

```bash
# Test that revoked credential no longer works
# GCP example:
gcloud auth activate-service-account --key-file=old-key.json
gcloud projects list  # Should fail with authentication error
```

### Step 4: Rotate the Credential

Generate new credential and update GitHub secret.

**Rotation Workflow**:

```bash
#!/bin/bash
# rotate-leaked-secret.sh
# Generate new credential and update GitHub

REPO="org/repo"
SECRET_NAME="DEPLOY_KEY"

# 1. Generate new credential
NEW_KEY=$(gcloud iam service-accounts keys create /dev/stdout \
  --iam-account=deployer@project.iam.gserviceaccount.com \
  --format=json | base64)

# 2. Update GitHub secret
gh secret set "${SECRET_NAME}" \
  --repo "${REPO}" \
  --body "${NEW_KEY}"

echo "✓ Secret ${SECRET_NAME} rotated in ${REPO}"

# 3. Verify new secret works
gh workflow run verify-deploy.yml \
  --repo "${REPO}"
```

**Update Dependencies**:

- Update secret in all repositories using it
- Update environment variables in deployment platforms
- Update configuration files referencing secret
- Notify teams using the credential

### Step 5: Remove from Git History

Leaked secrets remain in Git history even after revocation. Remove completely.

**BFG Repo-Cleaner (Recommended)**:

```bash
#!/bin/bash
# remove-secret-from-history.sh
