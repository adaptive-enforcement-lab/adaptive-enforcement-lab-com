---
title: Emergency Access
description: >-
  Break-glass procedures for production incidents with proper governance and documentation.
  Emergency access patterns that balance speed with accountability.
tags:
  - github
  - security
  - compliance
  - incident-response
  - operators
  - policy-enforcement
---

# Emergency Access

Production down. Revenue bleeding. Customers impacted. Normal approval workflows too slow.

!!! danger "Break-Glass Without Governance is Career-Limiting"
    Emergency access without audit trails, approval records, and post-incident review converts critical incidents into compliance violations. Speed matters. Documentation matters more.

Break-glass access exists for scenarios too urgent for standard bypass workflows. Speed is critical. Governance is mandatory.

---

## What is Break-Glass Access?

**Break-glass access**: Emergency procedure that grants immediate elevated access to resolve critical incidents, with mandatory post-incident documentation and review.

**Difference from bypass controls**: Bypass controls are planned, approved in advance, and time-boxed. Break-glass is unplanned, access first, approval documented retroactively.

**Without break-glass procedures**: Admin force-pushes to fix production outage. No record of who, when, or why. Compliance violation discovered in audit. Control failure.

**With break-glass procedures**: Admin triggers emergency workflow, gets immediate access, commits fix with justification, auto-generates incident ticket, flags for post-incident review. Compliance satisfied.

---

## When to Use Break-Glass

### Production Outage (SEV-1)

Service down. Revenue impact $10k/minute. CI pipeline broken. Status checks cannot pass. Normal bypass approval too slow.

**Emergency action**: Bypass status checks temporarily. Deploy fix directly. Restore protection after.

### Security Incident Response

Active breach detected. Attacker exploiting vulnerability in production. Fix requires immediate deployment.

**Emergency action**: Deploy security patch directly to main branch. Lock branch during deployment. Restore after verification.

### Data Loss Prevention

Database corruption detected. Force-push needed to reset repository state. Linear history protection blocks restoration.

**Emergency action**: Temporarily disable linear history requirement. Execute force-push restoration. Re-enable protection.

---

## Break-Glass Implementation Patterns

### Pattern 1: Monitored Force-Push

Allow force-push in emergency, but capture full audit trail.

```yaml
# .github/workflows/emergency-force-push.yml
name: Emergency Force-Push

on:
  workflow_dispatch:
    inputs:
      incident_ticket:
        description: 'Incident ticket ID (REQUIRED)'
        required: true
      justification:
        description: 'Why is break-glass necessary? (REQUIRED)'
        required: true
      target_branch:
        description: 'Target branch (default: main)'
        required: false
        default: 'main'

jobs:
  emergency-access:
    runs-on: ubuntu-latest
    environment: production-emergency
    steps:
      - name: Validate incident ticket
        env:
          TICKET_ID: ${{ github.event.inputs.incident_ticket }}
          PAGERDUTY_TOKEN: ${{ secrets.PAGERDUTY_TOKEN }}
        run: |
          # Verify incident exists and severity level
          INCIDENT=$(curl -s -H "Authorization: Token token=${PAGERDUTY_TOKEN}" \
            "https://api.pagerduty.com/incidents/${TICKET_ID}")

          SEVERITY=$(echo "${INCIDENT}" | jq -r '.incident.urgency')
          if [[ "${SEVERITY}" != "high" ]]; then
            echo "❌ Break-glass only authorized for high-urgency incidents"
            exit 1
          fi

      - name: Generate GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.ENFORCEMENT_APP_ID }}
          private-key: ${{ secrets.ENFORCEMENT_APP_PRIVATE_KEY }}
          owner: ${{ github.repository_owner }}

      - name: Backup current protection
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          REPO="${{ github.repository }}"
          BRANCH="${{ github.event.inputs.target_branch }}"

          gh api "repos/${REPO}/branches/${BRANCH}/protection" > protection-backup.json
          echo "BACKUP_SHA=$(sha256sum protection-backup.json | cut -d' ' -f1)" >> $GITHUB_ENV

      - name: Temporarily allow force-push
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          gh api --method PATCH \
            "repos/${{ github.repository }}/branches/${{ github.event.inputs.target_branch }}/protection" \
            -f allow_force_pushes=true

      - name: Log emergency access
        run: |
          cat > emergency-access.json <<EOF
          {
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "actor": "${{ github.actor }}",
            "repository": "${{ github.repository }}",
            "branch": "${{ github.event.inputs.target_branch }}",
            "incident_ticket": "${{ github.event.inputs.incident_ticket }}",
            "justification": "${{ github.event.inputs.justification }}",
            "protection_backup_sha": "${BACKUP_SHA}",
            "compliance_frameworks": ["SOC2-CC6.1", "ISO27001-A.16.1.5"],
            "auto_restore_scheduled": true
          }
          EOF

      - name: Upload audit evidence
        uses: actions/upload-artifact@v4
        with:
          name: emergency-access-${{ github.run_id }}
          path: |
            emergency-access.json
            protection-backup.json

      - name: Create incident review issue
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          gh issue create \
            --title "Emergency Access Review: ${{ github.event.inputs.incident_ticket }}" \
            --label "emergency-access,post-incident-review" \
            --body "$(cat <<EOF
          ## Emergency Access Event

          **Incident:** ${{ github.event.inputs.incident_ticket }}
          **Actor:** ${{ github.actor }}
          **Branch:** ${{ github.event.inputs.target_branch }}
          **Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

          ## Justification

          ${{ github.event.inputs.justification }}

          ## Post-Incident Actions Required

          - [ ] Verify protection restored after incident resolution
          - [ ] Review actions taken during emergency access period
          - [ ] Document lessons learned
          - [ ] Update runbook if procedure gaps identified

          ## Audit Evidence

          Evidence stored: \`emergency-access-${{ github.run_id }}\`
          EOF
          )"

      - name: Notify security team
        run: |
          curl -X POST "${{ secrets.SLACK_WEBHOOK_SECURITY }}" \
            -H "Content-Type: application/json" \
            -d '{
              "text": "🚨 Emergency Access Granted",
              "blocks": [{
                "type": "section",
                "text": {
                  "type": "mrkdwn",
                  "text": "*Emergency Access Granted*\n*Actor:* ${{ github.actor }}\n*Repository:* ${{ github.repository }}\n*Branch:* ${{ github.event.inputs.target_branch }}\n*Incident:* ${{ github.event.inputs.incident_ticket }}"
                }
              }]
            }'

      - name: Schedule auto-restore
        env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # Restore protection after 1 hour (safety net if manual restore missed)
          gh workflow run restore-protection.yml \
            -f repository="${{ github.repository }}" \
            -f branch="${{ github.event.inputs.target_branch }}" \
            -f backup_file="protection-backup.json" \
            -f delay="3600"
```

### Pattern 2: Emergency Commit Credentials

Break-glass credentials for direct commits during incidents.

```bash
#!/bin/bash
# emergency-access.sh
INCIDENT_ID="${1:?Incident ID required}"

# Verify incident severity
SEVERITY=$(curl -s -H "Authorization: Token token=${PAGERDUTY_TOKEN}" \
  "https://api.pagerduty.com/incidents/${INCIDENT_ID}" | jq -r '.incident.urgency')
[[ "${SEVERITY}" != "high" ]] && echo "❌ High-urgency incidents only" && exit 1

# Generate emergency token (1-hour TTL)
TOKEN=$(gh api --method POST "orgs/${ORG}/actions/runners/registration-token" --jq '.token')

# Log and store audit trail
LOG="{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"actor\":\"${USER}\",\"incident\":\"${INCIDENT_ID}\"}"
aws s3 cp - "s3://compliance-evidence/emergency-access/$(date +%Y/%m)/access-${INCIDENT_ID}.json" <<< "${LOG}"

# Create review ticket
gh issue create --repo "${ORG}/security-ops" \
  --title "Emergency Access Review: ${INCIDENT_ID}" --label "emergency-access"

echo "Emergency access token (expires in 1 hour): ${TOKEN}"
```

### Pattern 3: Admin Bypass with Mandatory Logging

Grant temporary admin privileges with automatic revocation.

```yaml
# .github/workflows/admin-bypass.yml
name: Emergency Admin Bypass
on:
  workflow_dispatch:
    inputs:
      incident_ticket:
        required: true
      admin_username:
        required: true

jobs:
  grant-bypass:
    runs-on: ubuntu-latest
    steps:
      - name: Grant and schedule revocation
        run: |
          gh api --method PUT \
            "orgs/${{ github.repository_owner }}/teams/emergency-admins/memberships/${{ github.event.inputs.admin_username }}"

          gh workflow run revoke-admin-bypass.yml \
            -f username="${{ github.event.inputs.admin_username }}" -f delay="3600"
```

---

## Post-Incident Review Process

### Automated Review Checklist

```markdown
## Emergency Access Post-Incident Review

**Incident:** [AUTO-FILLED] | **Granted:** [TIMESTAMP] | **Actor:** [USERNAME]

### Review Criteria
- [ ] Break-glass justified given incident severity
- [ ] Alternative solutions considered and rejected
- [ ] Protection restored after incident resolution
- [ ] All actions logged during emergency access period
- [ ] Compliance frameworks notified (if required)

### Evidence Verification
- [ ] Audit trail complete in compliance storage
- [ ] Protection backup and restoration confirmed
- [ ] Post-incident timeline documented

### Lessons Learned
- What went well: [TEAM FILLS IN]
- What could improve: [TEAM FILLS IN]
- Action items: [TEAM FILLS IN]
```

### Compliance Evidence Retention

Store break-glass events for 7-year compliance retention:

```bash
#!/bin/bash
# archive-emergency-access.sh

INCIDENT_ID="${1}"
EVIDENCE_FILE="emergency-access-${INCIDENT_ID}.json"

# Upload to compliance storage with 7-year retention
aws s3 cp "${EVIDENCE_FILE}" \
  "s3://compliance-evidence/emergency-access/$(date +%Y/%m)/${EVIDENCE_FILE}" \
  --metadata "retention=7years,compliance=SOC2,incident=${INCIDENT_ID}"

# Verify evidence integrity
CHECKSUM=$(sha256sum "${EVIDENCE_FILE}" | cut -d' ' -f1)
echo "{\"file\":\"${EVIDENCE_FILE}\",\"checksum\":\"${CHECKSUM}\",\"stored\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" | \
  aws s3 cp - "s3://compliance-evidence/emergency-access/$(date +%Y/%m)/${EVIDENCE_FILE}.checksum"
```

---

## Best Practices

**1. Require incident ticket for all break-glass actions**: No emergency access without active incident. Link every break-glass event to incident management system (PagerDuty, Jira Service Desk, etc.).

**2. Auto-restore protection within 1 hour**: Break-glass is temporary. Automatic restoration prevents forgotten re-enablement.

**3. Notify security team immediately**: Real-time alerts to security team Slack channel. Emergency access triggers scrutiny, even if authorized.

**4. Generate post-incident review ticket automatically**: Don't rely on manual follow-up. Workflow creates review issue on break-glass trigger.

**5. Store audit evidence in immutable storage**: S3 Object Lock, append-only logs. Auditors verify no tampering.

**6. Test break-glass procedures quarterly**: Drill break-glass workflows in non-production environments. Ensure procedures work when needed.

---

## Troubleshooting

**Break-glass workflow blocked**: Incident ticket validation failed. Verify incident exists in PagerDuty/incident system. Check severity level set to "high" or "critical".

**Protection not restored after incident**: Auto-restore workflow failed. Manually verify protection status: `gh api repos/ORG/REPO/branches/main/protection`. Restore from backup if needed.

**Audit evidence missing from storage**: Upload failed during emergency workflow. Retrieve evidence from workflow artifacts: `gh run download RUN_ID`. Re-upload to compliance storage manually.

**Post-incident review not created**: Issue creation step failed. Check GitHub App token permissions (`issues: write`). Create review issue manually using template.

See **[Troubleshooting](troubleshooting.md)** for additional issues.

---

## Related Patterns

- **[Bypass Controls](bypass-controls.md)**: Planned bypasses with pre-approval workflows
- **[Exception Management](exception-management.md)**: Permanent and temporary exception patterns
- **[Audit Evidence](audit-evidence.md)**: Evidence collection and storage patterns
- **[Compliance Reporting](compliance-reporting.md)**: Framework-specific emergency access reporting
- **[Drift Detection](drift-detection.md)**: Detecting unauthorized protection changes

---

## Next Steps

1. Create emergency access workflow in organization `.github` repository
2. Configure incident management system integration (PagerDuty, Jira)
3. Set up compliance evidence storage with 7-year retention
4. Deploy auto-restore workflows with 1-hour timeout
5. Create post-incident review issue template
6. Schedule quarterly break-glass procedure drills

---

*Production burned. Break-glass was triggered. Access granted immediately. Actions logged comprehensively. Protection auto-restored.
Post-incident review confirmed procedures followed. Auditors found complete evidence trail. The emergency was handled. The controls held.*
