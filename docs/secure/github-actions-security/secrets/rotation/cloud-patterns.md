---
title: Cloud-Specific Rotation Patterns
description: >-
  GCP service account rotation, Secrets Manager integration, and database credentials
---

            "${{ secrets.SLACK_WEBHOOK_URL }}"

```

### Secret Inventory Template

Maintain inventory file at `.github/secret-inventory.json`:

```json
{
  "secrets": [
    {
      "name": "PROD_DEPLOY_KEY",
      "tier": "Critical",
      "rotation_tier_days": 14,
      "last_rotated": "2026-01-01T00:00:00Z",
      "owner": "platform-team",
      "scope": "repository",
      "repositories": ["api-service"],
      "notes": "SSH key for production deployments"
    },
    {
      "name": "STAGING_API_TOKEN",
      "tier": "Medium",
      "rotation_tier_days": 90,
      "last_rotated": "2025-12-01T00:00:00Z",
      "owner": "dev-team",
      "scope": "organization",
      "repositories": ["api-service", "web-frontend"],
      "notes": "Third-party API token for staging environment"
    }
  ],
  "last_audit": "2026-01-01T00:00:00Z"
}
```

## Cloud-Specific Rotation Patterns

### GCP Service Account Key Rotation

```yaml
      - name: Rotate GCP service account key
        run: |
          # Create new key
          new_key=$(gcloud iam service-accounts keys create /dev/stdout \
            --iam-account=deploy@project.iam.gserviceaccount.com \
            --key-file-type=json)

          # Update GitHub secret
          echo "$new_key" | gh secret set GCP_SA_KEY

          # List old keys (created > 7 days ago)
          old_keys=$(gcloud iam service-accounts keys list \
            --iam-account=deploy@project.iam.gserviceaccount.com \
            --filter="validAfterTime < -P7D" \
            --format="value(name)")

          # Delete old keys after grace period
          for key in $old_keys; do
            gcloud iam service-accounts keys delete "$key" \
              --iam-account=deploy@project.iam.gserviceaccount.com \
              --quiet
          done
```

### Secrets Manager Integration

```yaml
      - name: Rotate secret in Secrets Manager
        run: |
          # Generate new random secret
          new_secret=$(openssl rand -base64 32)

          # Create new version in Secrets Manager
          echo -n "$new_secret" | \
            gcloud secrets versions add prod-api-key --data-file=-

          # Update GitHub Actions secret
          echo "$new_secret" | gh secret set PROD_API_KEY

          # Schedule old version deletion (7 days)
          old_version=$(gcloud secrets versions list prod-api-key \
            --filter="state=ENABLED" \
            --sort-by=~createTime \
            --limit=2 \
            --format="value(name)" | tail -n1)

          gcloud secrets versions destroy "$old_version" \
            --secret=prod-api-key \
            --etag=$(gcloud secrets versions describe "$old_version" --secret=prod-api-key --format="value(etag)")
```

### Database Credential Rotation

```yaml
      - name: Rotate database password
        run: |
          # Generate strong password
          new_password=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)

          # Update database user password
          psql -h db.example.com -U admin -c \
            "ALTER USER deploy_user WITH PASSWORD '$new_password';"

          # Update secret in Secrets Manager
          echo -n "$new_password" | \
            gcloud secrets versions add db-deploy-password --data-file=-

          # Update GitHub Actions secret
          echo "$new_password" | gh secret set DB_PASSWORD

          # Verify connection with new password
          PGPASSWORD="$new_password" psql -h db.example.com -U deploy_user -c "SELECT 1;"
```

## Emergency Rotation Procedures

When immediate rotation required due to suspected compromise.

### Breach Response Workflow

```yaml
name: Emergency Secret Rotation

on:
  workflow_dispatch:
    inputs:
      secret_name:
        description: 'Secret to rotate immediately'
        required: true
        type: string
      reason:
        description: 'Reason for emergency rotation'
        required: true
        type: choice
        options:
          - 'Found in logs'
          - 'Found in public repository'
          - 'Employee departure'
          - 'Service breach'
          - 'Other compromise'

permissions:
  contents: read
  issues: write  # Create incident ticket

jobs:
  emergency-rotate:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Create incident ticket
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh issue create \
            --title "🚨 Emergency Rotation: ${{ inputs.secret_name }}" \
            --label "security,incident,secrets" \
            --body "**Secret**: ${{ inputs.secret_name }}
          **Reason**: ${{ inputs.reason }}
          **Triggered by**: @${{ github.actor }}
          **Timestamp**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

          **Actions Required**:
          - [ ] Rotate credential immediately
          - [ ] Audit usage logs for unauthorized access
          - [ ] Review workflows with access to this secret
          - [ ] Determine blast radius
          - [ ] Update incident response documentation"

      - name: Revoke old credential immediately
        run: |
          # Cloud-specific revocation logic here
          echo "Revoking ${{ inputs.secret_name }} immediately"

      - name: Generate and deploy new credential
        run: |
          # Generate replacement credential
          echo "Generating new credential for ${{ inputs.secret_name }}"

      - name: Send alert to security team
        run: |
          # Send high-priority notification
          curl -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
            -H 'Content-Type: application/json' \
            -d '{
              "text": "🚨 EMERGENCY SECRET ROTATION",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Secret*: `${{ inputs.secret_name }}`\n*Reason*: ${{ inputs.reason }}\n*Triggered by*: @${{ github.actor }}"
                  }
                }
              ]
            }'
```

## Secret Rotation Checklist
