---
title: Credential Rotation and Security
description: >-
  Automated credential rotation patterns and security best practices for GitHub App credentials. Key rotation workflows.
---

# Credential Rotation and Security

## Automated Key Rotation

### GitHub Actions Rotation Workflow

Automate private key rotation with GitHub Actions.

```yaml
name: Rotate GitHub App Private Key

on:
  schedule:
    # Run quarterly on first day of quarter at 00:00 UTC
    - cron: '0 0 1 1,4,7,10 *'
  workflow_dispatch:

jobs:
  rotate-key:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Generate new private key
        id: new-key
        env:
          GH_TOKEN: ${{ secrets.ADMIN_PAT }}
          APP_SLUG: my-core-app
        run: |
          # Get app ID
          APP_ID=$(gh api /orgs/my-org/installations \
            --jq ".[] | select(.app_slug == \"$APP_SLUG\") | .app_id")

          # Generate new private key (requires admin PAT)
          RESPONSE=$(gh api -X POST /app/manifests/$APP_ID/conversions \
            -f manifest="$(cat app-manifest.json)")

          NEW_KEY=$(echo "$RESPONSE" | jq -r '.pem')
          echo "::add-mask::$NEW_KEY"
          echo "key=$NEW_KEY" >> $GITHUB_OUTPUT
          echo "app-id=$APP_ID" >> $GITHUB_OUTPUT

      - name: Update GitHub organization secret
        env:
          GH_TOKEN: ${{ secrets.ADMIN_PAT }}
          NEW_KEY: ${{ steps.new-key.outputs.key }}
          APP_ID: ${{ steps.new-key.outputs.app-id }}
        run: |
          # Update CORE_APP_PRIVATE_KEY
          gh secret set CORE_APP_PRIVATE_KEY \
            --org my-org \
            --body "$NEW_KEY"

          # Verify app ID hasn't changed
          CURRENT_APP_ID=$(gh secret list --org my-org \
            --json name,value | jq -r '.[] | select(.name == "CORE_APP_ID") | .value')

          if [ "$CURRENT_APP_ID" != "$APP_ID" ]; then
            echo "Warning: App ID changed from $CURRENT_APP_ID to $APP_ID"
            gh secret set CORE_APP_ID --org my-org --body "$APP_ID"
          fi

      - name: Notify rotation
        if: always()
        run: |
          gh api /repos/my-org/security-team/issues \
            -X POST \
            -f title="GitHub App private key rotated" \
            -f body="Private key for Core App was automatically rotated on $(date -u +%Y-%m-%d)"
```

!!! tip "Rotation Best Practices"

    - **Quarterly rotation** - Balance security with operational overhead
    - **Automated notification** - Alert security team on rotation
    - **Validation testing** - Test new credentials before removing old ones
    - **Rollback plan** - Keep previous key for 24 hours in case of issues

### Vault Rotation Policy

Configure automatic rotation in HashiCorp Vault.

```hcl
# rotation-policy.hcl
path "secret/data/github-app" {
  capabilities = ["create", "update", "read"]
}

# Rotation policy - rotate every 90 days
rotation "github-app-key" {
  path        = "secret/data/github-app"
  interval    = "2160h" # 90 days

  rotate {
    # Custom rotation script
    command = "/opt/vault/scripts/rotate-github-app.sh"
  }
}
```

**Rotation script** (`rotate-github-app.sh`):

```bash
#!/bin/bash
set -e

# Generate new GitHub App private key via API
NEW_KEY=$(curl -X POST \
  -H "Authorization: Bearer $GITHUB_ADMIN_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/manifests/$GITHUB_APP_ID/conversions" \
  | jq -r '.pem')

# Update Vault secret
vault kv put secret/github-app \
  app_id="$GITHUB_APP_ID" \
  private_key="$NEW_KEY"

# Trigger External Secrets refresh
kubectl annotate externalsecret github-app-credentials \
  --namespace automation \
  force-sync="$(date +%s)" \
  --overwrite
```

### AWS Secrets Manager Rotation

Configure rotation using AWS Lambda.

**1. Create rotation Lambda function**:

```python
import boto3
import json
import requests
import os

def lambda_handler(event, context):
    service_client = boto3.client('secretsmanager')
    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    if step == "createSecret":
        # Generate new GitHub App key
        github_token = os.environ['GITHUB_ADMIN_TOKEN']
        app_id = os.environ['GITHUB_APP_ID']

        response = requests.post(
            f'https://api.github.com/app/manifests/{app_id}/conversions',
            headers={
                'Authorization': f'Bearer {github_token}',
                'Accept': 'application/vnd.github+json'
            }
        )

        new_key = response.json()['pem']
        new_secret = {
            'app_id': app_id,
            'private_key': new_key
        }

        # Store new version
        service_client.put_secret_value(
            SecretId=arn,
            ClientRequestToken=token,
            SecretString=json.dumps(new_secret),
            VersionStages=['AWSPENDING']
        )

    elif step == "setSecret":
        # Test new secret works
        current = service_client.get_secret_value(
            SecretId=arn,
            VersionId=token,
            VersionStage='AWSPENDING'
        )
        # Add validation logic here

    elif step == "testSecret":
        # Validate new key works
        pass

    elif step == "finishSecret":
        # Promote AWSPENDING to AWSCURRENT
        metadata = service_client.describe_secret(SecretId=arn)
        current_version = None
        for version, stages in metadata['VersionIdsToStages'].items():
            if 'AWSCURRENT' in stages:
                current_version = version
                break

        service_client.update_secret_version_stage(
            SecretId=arn,
            VersionStage='AWSCURRENT',
            MoveToVersionId=token,
            RemoveFromVersionId=current_version
        )
```

**2. Configure rotation**:

```bash
aws secretsmanager rotate-secret \
  --secret-id github-app-credentials \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:rotate-github-app \
  --rotation-rules AutomaticallyAfterDays=90
```

### Rotation Comparison

| Method | Automation | Complexity | Downtime | Rollback | Best For |
| -------- | ------------ | ------------ | ---------- | ---------- | ---------- |
| **GitHub Actions** | Scheduled workflow | Low | Minimal (seconds) | Manual | GitHub-centric orgs |
| **Vault Policy** | Built-in rotation | Medium | None | Automatic | Multi-platform |
| **AWS Lambda** | Secrets Manager rotation | Medium | None | Automatic | AWS-native stacks |
| **Manual** | None | Low | Minutes | Manual | Small teams |

## Security Best Practices

### Secret Storage Checklist

- [ ] Secrets stored in secure vault (GitHub Secrets, Vault, AWS Secrets Manager)
- [ ] Secrets never committed to Git repositories
- [ ] Secrets masked in CI/CD logs
- [ ] Secrets scoped to minimum required repositories/environments
- [ ] Organization secrets used for shared GitHub Apps
- [ ] Environment protection enabled for production secrets
- [ ] Secret rotation schedule documented and automated
- [ ] Audit logging enabled for secret access
- [ ] Access to secrets limited to required personnel
- [ ] Backup/recovery procedure documented

### Access Control Principles

!!! success "Do"

    - **Principle of least privilege** - Grant minimum required access
    - **Environment-based scoping** - Use different credentials for dev/staging/prod
    - **Regular access reviews** - Audit who has access quarterly
    - **Automated rotation** - Rotate credentials every 90 days
    - **Monitoring and alerting** - Track secret usage and alert on anomalies

!!! danger "Don't"

    - Never commit secrets to Git (even private repositories)
    - Never log or expose secrets in workflow output
    - Never share secrets via unsecured channels (email, chat)
    - Never use the same credentials across environments
    - Never skip secret masking in CI/CD configurations

### Compliance and Auditing

#### GitHub Audit Log Monitoring

Monitor organization secrets access:

```bash
# Query organization audit log for secret access
gh api /orgs/my-org/audit-log \
  --jq '.[] | select(.action == "org.update_actions_secret") | {
    timestamp: .created_at,
    actor: .actor,
    secret: .data.secret_name
  }'
```

#### Secret Usage Tracking

Track which workflows access secrets:

```yaml
# Add to workflow for audit trail
- name: Log secret usage
  run: |
    echo "Workflow: ${{ github.workflow }}"
    echo "Repository: ${{ github.repository }}"
    echo "Actor: ${{ github.actor }}"
    echo "Ref: ${{ github.ref }}"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Send to logging system for compliance
```

## Related Documentation

- [Authentication Decision Guide](../authentication-decision-guide.md) - Choose the right authentication method
- [Security Best Practices](../security-best-practices.md) - Comprehensive security guidelines
- [JWT Authentication](../../../patterns/github-actions/actions-integration/jwt-authentication/index.md) - JWT token generation patterns
- [Token Lifecycle Management](../../../patterns/github-actions/actions-integration/token-lifecycle/index.md) - Token refresh and expiration handling
- [Error Handling](../../../patterns/github-actions/actions-integration/error-handling/index.md) - Error handling for token operations
