---
title: Secret Scanning Integration
description: >-
  GitHub secret scanning configuration, push protection, custom pattern definitions,
  and response playbook for detected credentials in GitHub Actions workflows.
tags:
  - github-actions
  - security
  - secrets
  - scanning
  - detection
---

# Secret Scanning Integration

Prevention is good. Detection is essential. Assume secrets will leak. Build systems to catch them before damage spreads.

!!! danger "The Risk"

    Secrets leak through commits, workflow logs, artifacts, pull requests, and third-party integrations. Without automated scanning, credentials remain exposed for days or months before detection. By then, your infrastructure is already compromised.

## What is Secret Scanning?

GitHub secret scanning automatically detects known secret formats in repositories, workflow logs, and commit history.

**How It Works**:

1. GitHub scans commits, issues, pull requests, and workflow logs
2. Pattern matching identifies known credential formats (API keys, tokens, certificates)
3. Alerts sent to repository administrators and security team
4. Optional push protection blocks commits containing secrets
5. Partner notification for compromised service provider credentials

**Coverage**:

- **Repository scanning**: All commits, branches, and history
- **Push protection**: Block secret commits before they land
- **Workflow logs**: Scan job output for leaked credentials
- **Pull requests**: Scan fork contributions for secret exposure
- **Partner patterns**: 200+ service providers receive breach notifications

## Enabling Secret Scanning

Secret scanning availability depends on repository visibility and GitHub plan.

### Repository Settings

**GitHub Advanced Security (GHAS) Required**:

- Private/internal repositories: GHAS license required
- Public repositories: Free, enabled by default

**Enable via Settings**:

1. Navigate to `Settings → Code security and analysis`
2. Enable **Secret scanning**
3. Enable **Push protection** (recommended)
4. Enable **Non-provider patterns** for generic secrets

```yaml
# .github/workflows/verify-security.yml
# Workflow to enforce security features are enabled

name: Verify Security Configuration
on:
  schedule:
    - cron: '0 8 * * 1'  # Weekly Monday 8 AM
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-scanning:
    runs-on: ubuntu-latest
    steps:
      - name: Check secret scanning enabled
        uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            const { data: repo } = await github.rest.repos.get({
              owner: context.repo.owner,
              repo: context.repo.repo
            });

            const required = [
              { setting: 'security_and_analysis.secret_scanning.status', name: 'Secret Scanning' },
              { setting: 'security_and_analysis.secret_scanning_push_protection.status', name: 'Push Protection' }
            ];

            for (const check of required) {
              const value = check.setting.split('.').reduce((o, k) => o?.[k], repo);
              if (value !== 'enabled') {
                core.setFailed(`${check.name} is not enabled (status: ${value})`);
              } else {
                core.info(`✓ ${check.name} enabled`);
              }
            }
```

### Organization-Level Enablement

Enable secret scanning across all repositories in organization.

**Organization Settings**:

1. Navigate to `Organization Settings → Code security and analysis`
2. Enable **Secret scanning** for all repositories
3. Enable **Push protection** organization-wide
4. Configure **Custom patterns** for org-specific secrets

**Enforcement via API**:

```bash
#!/bin/bash
# enable-secret-scanning.sh
# Enable secret scanning and push protection for all org repos

ORG="your-org"
TOKEN="${GITHUB_TOKEN}"

# Get all repositories in organization
repos=$(gh api \
  --paginate \
  "/orgs/${ORG}/repos" \
  --jq '.[].name')

for repo in $repos; do
  echo "Enabling secret scanning for ${ORG}/${repo}..."

  # Enable secret scanning
  gh api \
    --method PATCH \
    "/repos/${ORG}/${repo}" \
    -f security_and_analysis[secret_scanning][status]=enabled \
    -f security_and_analysis[secret_scanning_push_protection][status]=enabled

  echo "✓ ${repo} configured"
done
```

**Best Practices**:

- Enable organization-wide by default
- Require for all new repositories
- Audit compliance weekly
- Block repository creation without security features

## Push Protection

Push protection blocks commits containing secrets before they reach GitHub.

### How Push Protection Works

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as Git Client
    participant GH as GitHub
    participant Scan as Secret Scanner

    Dev->>Git: git push origin main
    Git->>GH: Push commit
    GH->>Scan: Scan commit contents

    alt Secret Detected
        Scan-->>GH: Secret found (API key pattern)
        GH-->>Git: ❌ Push rejected
        Git-->>Dev: Error: secret detected<br/>Remove secret and retry
    else No Secret
        Scan-->>GH: No secrets found
        GH-->>Git: ✓ Push accepted
        Git-->>Dev: Push successful
    end
```

### Bypassing Push Protection

Developers can bypass push protection for false positives. Track bypasses for security review.

**Bypass Process**:

1. Developer attempts push with secret
2. GitHub blocks push with bypass option
3. Developer provides justification (false positive, test credential, will revoke)
4. Push allowed with bypass event logged
5. Security team reviews bypass audit trail

**Bypass Workflow**:

```bash
# Developer pushes commit with secret
git push origin main
# > Error: secret detected in commit abc123
# > To bypass, visit: https://github.com/org/repo/security/bypass/abc123

# Developer bypasses with justification
# GitHub logs bypass event

# Security team reviews bypasses
gh api /repos/org/repo/secret-scanning/push-protection-bypasses
```

**Monitor Bypasses**:

```yaml
# .github/workflows/monitor-bypasses.yml
# Alert security team when push protection bypassed

name: Monitor Push Protection Bypasses
on:
  schedule:
    - cron: '0 */4 * * *'  # Every 4 hours
  workflow_dispatch:

permissions:
  contents: read

jobs:
  check-bypasses:
    runs-on: ubuntu-latest
    steps:
      - name: Get recent bypasses
        uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1
        with:
          script: |
            const bypasses = await github.paginate(
              github.rest.secretScanning.listPushProtectionBypasses,
              {
                owner: context.repo.owner,
                repo: context.repo.repo
              }
            );

            const recent = bypasses.filter(b => {
              const created = new Date(b.created_at);
              const fourHoursAgo = new Date(Date.now() - 4 * 60 * 60 * 1000);
              return created > fourHoursAgo;
            });

            if (recent.length > 0) {
              core.warning(`${recent.length} push protection bypasses in last 4 hours`);
              for (const bypass of recent) {
                core.warning(`Bypass by ${bypass.pusher.login}: ${bypass.token_type}`);
              }
              // Trigger alert to security team (Slack, PagerDuty, etc.)
            }
```

## Custom Pattern Definitions

Define organization-specific secret patterns for internal credentials.

### Creating Custom Patterns

Custom patterns use regular expressions to detect organization-specific secrets.

**Pattern Format**:

```regex
# Pattern components
(?i)                           # Case insensitive
\b                             # Word boundary
(internal_api_key|secret_key)  # Secret identifier
[\s:=]+                        # Separator
([a-f0-9]{64})                 # Secret value pattern
\b                             # Word boundary
```

**Organization-Level Pattern**:

1. Navigate to `Organization Settings → Code security → Secret scanning`
2. Click **New pattern**
3. Define pattern name and regular expression
4. Test against sample secrets
5. Enable for all or selected repositories

**Example Custom Patterns**:

| Secret Type | Pattern | Example Match |
| ----------- | ------- | ------------- |
| Internal API Key | `(?i)\b(internal_api_key\s*[:=]\s*)([a-f0-9]{64})\b` | `INTERNAL_API_KEY=a1b2c3d4...` |
| Service Token | `(?i)\bSVC_TOKEN_([A-Z0-9]{32})\b` | `SVC_TOKEN_AB12CD34EF56GH78...` |
| Database URL | `(?i)postgresql://[^:]+:[^@]+@[^/]+/\w+` | `postgresql://user:pass@host/db` |
| SSH Private Key | `-----BEGIN (RSA\|OPENSSH) PRIVATE KEY-----` | `-----BEGIN RSA PRIVATE KEY-----` |

### Pattern Best Practices

**Effective Patterns**:

- Use word boundaries `\b` to avoid substring false positives
- Include secret identifier context (e.g., `API_KEY=`)
- Match actual secret format (length, character class)
- Test against real examples before deployment
- Document pattern purpose and maintenance owner

**Avoid Common Mistakes**:

- Too broad: `[a-z0-9]+` (matches everything)
- Too narrow: `PROD_KEY=abc123` (only matches one value)
- Missing boundaries: `password.*` (matches variable names)
- No context: `[a-f0-9]{64}` (many false positives)

**Test Pattern**:

```bash
# Test custom pattern against sample file
echo "INTERNAL_API_KEY=a1b2c3d4e5f6..." > test-secret.txt

# GitHub CLI test (pattern must be created first)
gh secret-scanning list --repo org/repo

# Local regex test
grep -P '(?i)\b(internal_api_key\s*[:=]\s*)([a-f0-9]{64})\b' test-secret.txt
```

## Secret Scanning Alerts

Alerts notify repository administrators when secrets are detected.

### Alert Triage Workflow

```mermaid
flowchart TD
    Alert["Secret Detected"] --> Verify["1. Verify Alert<br/>Real or False Positive?"]

    Verify -->|Real Secret| Classify["2. Classify Severity<br/>Production or Test?"]
    Verify -->|False Positive| Dismiss["Dismiss as<br/>False Positive"]

    Classify -->|Production Credential| Critical["🔴 CRITICAL<br/>Immediate Response"]
    Classify -->|Test/Dev Credential| Medium["🟡 MEDIUM<br/>Standard Response"]

    Critical --> Revoke1["3a. Revoke credential<br/>(within 15 minutes)"]
    Medium --> Revoke2["3b. Revoke credential<br/>(within 24 hours)"]

    Revoke1 --> Rotate1["4a. Rotate credential<br/>Update GitHub secret"]
    Revoke2 --> Rotate2["4b. Rotate credential<br/>Update GitHub secret"]

    Rotate1 --> Clean1["5a. Remove from history<br/>BFG Repo-Cleaner"]
    Rotate2 --> Clean2["5b. Remove from history<br/>Git filter-branch"]

    Clean1 --> Document1["6. Document incident"]
    Clean2 --> Document2["6. Document incident"]

    style Alert fill:#66d9ef,color:#1b1d1e
    style Critical fill:#f92572,color:#1b1d1e
    style Medium fill:#e6db74,color:#1b1d1e
    style Dismiss fill:#75715e,color:#f8f8f2
```

### Alert Response Playbook

Follow this runbook when secret scanning detects a credential.

#### Step 1: Verify the Alert

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

#### Step 2: Classify Severity

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

#### Step 3: Revoke the Credential

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

#### Step 4: Rotate the Credential

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

#### Step 5: Remove from Git History

Leaked secrets remain in Git history even after revocation. Remove completely.

**BFG Repo-Cleaner (Recommended)**:

```bash
#!/bin/bash
# remove-secret-from-history.sh
# Remove leaked secret from all Git history

# 1. Clone mirror
git clone --mirror https://github.com/org/repo.git repo-mirror
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

#### Step 6: Document the Incident

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

- Use [OIDC federation](oidc.md) instead of long-lived secrets
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
- [OIDC Federation Patterns](oidc.md)
- [Secret Rotation Automation](rotation.md)
- [Workflow Trigger Security](../workflows/triggers.md)
