---
title: Secret Scanning Alert Response
description: >-
  Alert triage workflow, incident response playbook, and emergency revocation procedures for leaked credentials in repositories
---

!!! warning "Revoke First, Investigate Later"

    When secret scanning alerts trigger, revoke the credential immediately before investigating. Leaked credentials are compromised the moment they reach GitHub. Speed of revocation determines blast radius.

## Remove Secret from Git History

```bash
# 1. Clone mirror

git clone --mirror <https://github.com/org/repo.git> repo-mirror
cd repo-mirror

# 2. Create file with secret to remove

echo "a1b2c3d4e5f6leaked_secret_value" > ../secret-values.txt

# 3. Run BFG to remove secret

bfg --replace-text ../secret-values.txt .

# 4. Clean up and force push

git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 5. Force push (requires admin access)

git push --force

echo "⚠ Secret removed from history. All developers must re-clone."
```

**Alternative: Git Filter-Branch**:

```bash
# Remove specific file from all history
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch path/to/secret-file.env' \
  --prune-empty --tag-name-filter cat -- --all

# Force push
git push origin --force --all
git push origin --force --tags
```

**Post-Cleanup**:

- Notify all team members to re-clone repository
- Old clones still contain secret in history
- Update protected branch rules if force push blocked
- Monitor for secret re-introduction

## Step 6: Document the Incident

Create incident report for security audit trail.

**Incident Template**:

```markdown
# Secret Leak Incident Report

**Date**: 2026-01-02
**Severity**: Critical
**Status**: Resolved

## Summary

Production GCP service account key leaked in commit abc123 to `main` branch.

## Timeline

- **15:23 UTC**: Secret committed to repository
- **15:30 UTC**: Secret scanning alert triggered
- **15:35 UTC**: Security team notified via Slack
- **15:40 UTC**: Credential revoked in GCP console
- **15:50 UTC**: New credential generated and rotated
- **16:00 UTC**: Secret removed from Git history
- **16:30 UTC**: All workflows verified with new credential

## Impact

- Credential exposed for 17 minutes before revocation
- No evidence of unauthorized access in audit logs
- Zero production impact, deployments continued with new credential

## Root Cause

Developer committed `.env` file containing production credential.
File should have been in `.gitignore`.

## Actions Taken

- [x] Credential revoked immediately
- [x] New credential generated and rotated
- [x] Secret removed from Git history with BFG
- [x] Added `.env` to `.gitignore`
- [x] Custom secret pattern added for this credential type
- [x] Team training scheduled on secret management

## Prevention

- Update `.gitignore` template to include `.env` files
- Enable push protection organization-wide
- Add pre-commit hook to scan for secrets locally
- Deploy git-secrets to all developer workstations
```

### Automated Alert Notifications

Integrate secret scanning alerts with incident response tools.

**Slack Notification**:

```yaml
# .github/workflows/secret-alert-notification.yml
# Send Slack alert when secret detected

name: Secret Scanning Alert
on:
  secret_scanning_alert:
    types: [created, reopened]

permissions:
  contents: read

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Send Slack alert
        uses: slackapi/slack-github-action@70cd7be8e40a46e8b0eced40b0de447bdb42f68e  # v1.26.0
        with:
          webhook-url: ${{ secrets.SLACK_SECURITY_WEBHOOK }}
          webhook-type: incoming-webhook
          payload: |
            {
              "text": "🔴 Secret Detected in Repository",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Secret Detected: ${{ github.event.alert.secret_type }}*\n\nRepository: ${{ github.repository }}\nLocation: ${{ github.event.alert.locations[0].path }}\nAlert: ${{ github.event.alert.html_url }}"
                  }
                },
                {
                  "type": "actions",
                  "elements": [
                    {
                      "type": "button",
                      "text": {
                        "type": "plain_text",
                        "text": "View Alert"
                      },
                      "url": "${{ github.event.alert.html_url }}"
                    }
                  ]
                }
              ]
            }
```

## Pre-Commit Secret Scanning

Catch secrets before they reach GitHub with local pre-commit hooks.

### Git-Secrets Integration

```bash
# Install git-secrets (macOS)
brew install git-secrets

# Install in repository
cd /path/to/repo
git secrets --install

# Add patterns for AWS credentials
git secrets --register-aws

# Add custom patterns
git secrets --add 'INTERNAL_API_KEY[:=][a-f0-9]{64}'
git secrets --add 'postgresql://[^:]+:[^@]+@'

# Scan repository for secrets
git secrets --scan

# Scan entire history
git secrets --scan-history
```

### Pre-Commit Framework

```yaml
# .pre-commit-config.yaml
# Pre-commit hooks for secret detection

repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.1
    hooks:
      - id: gitleaks

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

# Install hooks
# pre-commit install
```

**Developer Workflow**:

```bash
# Attempt commit with secret
git add .
git commit -m "Add deployment config"

# Pre-commit hook runs
# > [gitleaks] Detecting secrets...
# > Error: Secret detected in deployment.yml
# > Commit blocked

# Remove secret and retry
git commit -m "Add deployment config (secret removed)"
# > [gitleaks] No secrets detected
# > Commit successful
```

## Troubleshooting

| Issue | Cause | Solution |
| ----- | ----- | -------- |
| **Secret scanning not detecting known pattern** | Non-provider pattern disabled | Enable "Non-provider patterns" in repository settings |
| **Push protection blocking false positive** | Legitimate value matches pattern | Bypass with justification, then add to allow list |
| **Alert for already-revoked credential** | Secret still in Git history | Run BFG Repo-Cleaner to remove from history |
| **Cannot bypass push protection** | Organization policy requires admin | Contact repository admin or security team |
| **Custom pattern not triggering alerts** | Regex syntax error or too broad | Test pattern with `grep -P` before deployment |
| **Pre-commit hook not running** | Hooks not installed | Run `git secrets --install` in repository |

## Security Best Practices

**Detection**:

- Enable secret scanning organization-wide
- Enable push protection to prevent commits with secrets
- Define custom patterns for organization-specific credentials
- Monitor bypass events for policy violations

**Prevention**:

- Use [OIDC federation](../oidc/index.md) instead of long-lived secrets
- Add `.env`, `*.key`, `*.pem` to `.gitignore`
- Deploy pre-commit hooks to all developer workstations
- Educate team on secret management during onboarding

**Response**:

- Document incident response playbook
- Automate revocation scripts for common credential types
- Integrate alerts with security team communication channels
- Track mean time to revocation (MTTR) as security metric

**Monitoring**:

- Weekly review of secret scanning alerts
- Monthly audit of bypass justifications
- Quarterly review of custom pattern effectiveness
- Annual rotation of all long-lived credentials

## Related Resources

- [Secret Management Overview](index.md)
- [OIDC Federation Patterns](../oidc/index.md)
- [Secret Rotation Automation](../rotation/index.md)
- [Workflow Trigger Security](../../workflows/triggers/index.md)
