---
title: Maintenance
description: >-
  Ongoing care and lifecycle management for GitHub Core Apps.
  Key rotation, permission audits, and health monitoring.
---

# Maintenance

Ongoing care, key rotation, and lifecycle management for your GitHub Core App.

## Regular Tasks

| Task | Frequency | Action |
|------|-----------|--------|
| **Permission Review** | Quarterly | Audit and adjust permissions |
| **Key Rotation** | Semi-annually | Generate new private key |
| **Usage Audit** | Monthly | Review audit logs |
| **Secret Access** | Quarterly | Review who can access secrets |

## Key Rotation Process

!!! warning "Plan Ahead"

    Schedule key rotation during low-activity periods to minimize disruption.

### Step 1: Generate New Key

1. Navigate to app settings in GitHub
2. Scroll to **Private keys** section
3. Click **Generate a private key**
4. Download and secure the new `.pem` file

### Step 2: Update Secrets

1. Navigate to organization/repository secrets
2. Update `CORE_APP_PRIVATE_KEY` with new key contents
3. Verify the update saved successfully

### Step 3: Verify Authentication

```yaml
# Test workflow
- name: Test new key
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}

- name: Verify token works
  run: gh api /rate_limit
  env:
    GH_TOKEN: ${{ steps.token.outputs.token }}
```

### Step 4: Delete Old Key

1. Return to app settings
2. Find the old private key
3. Click **Delete** next to the old key
4. Confirm deletion

### Step 5: Document

Record in security log:

- Date of rotation
- Who performed rotation
- Verification status
- Any issues encountered

## Permission Audits

### Quarterly Review Checklist

- [ ] List all workflows using the app
- [ ] Verify each permission is still needed
- [ ] Remove unused permissions
- [ ] Document permission justification
- [ ] Update internal documentation

### Audit Script

```bash
# List app permissions
gh api /apps/{APP_SLUG} --jq '.permissions'

# List installation repositories
gh api /installation/repositories --jq '.repositories[].full_name'
```

## Usage Monitoring

### Audit Log Queries

```bash
# App API activity (last 30 days)
gh api "/orgs/{ORG}/audit-log" \
  --jq '.[] | select(.actor | contains("app/"))' \
  | head -50
```

### Rate Limit Tracking

```bash
# Current rate limit status
gh api /rate_limit --jq '{
  limit: .rate.limit,
  remaining: .rate.remaining,
  reset: .rate.reset | todate
}'
```

## Decommissioning

When removing a Core App:

### Step 1: Identify Dependencies

```bash
# Search for app usage in workflows
grep -r "CORE_APP" .github/workflows/
```

### Step 2: Migration Plan

1. Identify replacement authentication method
2. Update affected workflows
3. Test new authentication
4. Document migration steps

### Step 3: Communication

Notify affected teams:

- Date of decommissioning
- Migration instructions
- Support contact

### Step 4: Uninstall

1. Navigate to app settings
2. Click **Uninstall** in danger zone
3. Confirm uninstallation

### Step 5: Cleanup

1. Delete `CORE_APP_ID` secret
2. Delete `CORE_APP_PRIVATE_KEY` secret
3. Delete the app itself (if no longer needed)

### Step 6: Verification

```bash
# Confirm workflows still function
gh workflow run test.yml
gh run list --workflow=test.yml --limit=1
```

## Maintenance Calendar

!!! example "Suggested Schedule"

    | Month | Task |
    |-------|------|
    | January | Permission audit |
    | March | Key rotation |
    | April | Permission audit |
    | June | Usage review |
    | July | Permission audit |
    | September | Key rotation |
    | October | Permission audit |
    | December | Annual review |

## Documentation

Maintain these records:

- App configuration details
- Permission justification
- Key rotation history
- Audit findings
- Incident reports

!!! tip "Documentation Location"

    Store app documentation in a private repository or internal wiki accessible to the infrastructure team.
