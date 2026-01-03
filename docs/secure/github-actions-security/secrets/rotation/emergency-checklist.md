---
title: Emergency Rotation and Checklist
description: >-
  Breach response workflow, rotation checklist, and common mistakes
---

Before implementing rotation:

- [ ] **Inventory secrets**: Document all secrets, owners, and rotation tiers
- [ ] **Assign rotation frequencies**: Map secrets to Critical/High/Medium/Low tiers
- [ ] **Set up monitoring**: Create expiration tracking workflow
- [ ] **Test dual-key pattern**: Verify service accepts both old and new credentials
- [ ] **Automate rotation**: Create scheduled workflows for each secret type
- [ ] **Configure notifications**: Set up Slack/email alerts for expiring secrets
- [ ] **Document procedures**: Write runbooks for manual rotation steps
- [ ] **Test emergency rotation**: Verify breach response workflow works
- [ ] **Schedule rotation windows**: Choose low-traffic times for production rotations
- [ ] **Audit rotation history**: Review Secret Manager versions regularly

## Common Rotation Mistakes

### Mistake 1: Immediate Revocation

**Problem**: Rotating secret and immediately revoking old value breaks active workflows.

**Fix**: Use dual-secret pattern with 7-day grace period.

### Mistake 2: No Verification

**Problem**: New credential doesn't work, outage occurs before detection.

**Fix**: Always verify new credential before revoking old one.

```yaml
- name: Verify new credential
  run: |
    # Test deployment with new key
    ./test-deployment.sh --key="$NEW_KEY" || exit 1
```

### Mistake 3: Missing Inventory

**Problem**: Rotating one copy of credential, missing duplicate stored elsewhere.

**Fix**: Maintain secret inventory in `.github/secret-inventory.json`.

### Mistake 4: No Rollback Plan

**Problem**: Rotation breaks production, no way to restore old credential.

**Fix**: Store old credential version in Secrets Manager for 30 days post-rotation.

```yaml
- name: Archive old credential
  run: |
    # Keep old version for emergency rollback
    gcloud secrets versions disable previous --secret=deploy-key
    # Auto-delete after 30 days
    gcloud secrets versions destroy previous \
      --secret=deploy-key \
      --ttl=30d
```

### Mistake 5: Hardcoded Rotation

**Problem**: Rotation scripts contain service-specific logic, not reusable.

**Fix**: Use reusable workflows with secret type parameters.

```yaml
# .github/workflows/rotate-secret-template.yml
on:
  workflow_call:
    inputs:
      secret_name:
        required: true
        type: string
      secret_type:
        required: true
        type: string
      rotation_tier:
        required: true
        type: string
```

## OIDC Alternative: Eliminate Rotation

The best secret rotation strategy is no secrets at all.

**When to Use OIDC Instead**:

- Cloud provider authentication (AWS, GCP, Azure)
- Service accounts for deployments
- Temporary access to external APIs

**Benefits Over Rotation**:

- No stored credentials to rotate
- Tokens expire automatically (minutes, not months)
- Cryptographic binding to workflow context
- Zero operational overhead

See [OIDC Federation Patterns](oidc.md) for implementation.

## Security Best Practices

**Prefer OIDC**: Eliminate rotation burden entirely where possible.

**Automate everything**: Manual rotation doesn't scale and introduces human error.

**Grace periods matter**: Never revoke old credential until new one verified.

**Monitor rotation failures**: Failed rotation indicates potential compromise.

**Audit rotation history**: Review Secret Manager versions to detect anomalies.

**Document secret owners**: Every secret must have responsible team in inventory.

**Test emergency procedures**: Run breach response drills quarterly.

**Encrypt inventory file**: `.github/secret-inventory.json` contains sensitive metadata.

**Use environment secrets for production**: Rotation workflows require approval gates.

**Log rotation events**: Send rotation success/failure to security SIEM.

## Next Steps

Ready to implement rotation automation? Continue with:

- **[OIDC Federation Patterns](oidc.md)**: Eliminate stored secrets entirely with secretless cloud authentication
- **[Secret Scanning Integration](scanning.md)**: Detect leaked secrets before rotation becomes emergency response
- **[Secret Management Overview](index.md)**: Storage hierarchy, threat model, and exposure prevention

## Quick Reference

### Rotation Tier Schedule

| Tier | Rotation Frequency | Grace Period | Notification Lead Time |
| ---- | ------------------ | ------------ | ---------------------- |
| **Critical** | 7-14 days | 7 days | 3 days |
| **High** | 30 days | 7 days | 7 days |
| **Medium** | 90 days | 14 days | 14 days |
| **Low** | 180 days | 30 days | 30 days |

### Rotation Workflow Pattern

| Phase | Timing | Action | Verification |
| ----- | ------ | ------ | ------------ |
| **Generate** | T-0 | Create new credential | Format validation |
| **Store** | T+1h | Add to Secrets Manager | Version created |
| **Deploy** | T+24h | Update GitHub secret | Secret accessible |
| **Verify** | T+48h | Test with new credential | Workflow succeeds |
| **Revoke** | T+7d | Delete old credential | Old key fails |
| **Cleanup** | T+14d | Remove temporary secrets | Inventory updated |

### Emergency Rotation Triggers

| Event | Response Time | Revocation | Notification |
| ----- | ------------- | ---------- | ------------ |
| **Found in logs** | Immediate | Revoke old immediately | Security team + managers |
| **Public repository** | Immediate | Revoke old immediately | Security team + CISO |
| **Employee departure** | 1 hour | Revoke within 4 hours | Security team |
| **Service breach** | 4 hours | Coordinate with vendor | Security team + stakeholders |
| **Workflow modification** | 24 hours | Audit before revocation | Repository maintainers |

---

!!! tip "Rotation is Risk Management, Not Security Theater"

    Rotate secrets to limit blast radius when credentials leak, not to prevent leaks. Every secret will eventually be compromised. Rotation determines how much damage attackers can do with stolen credentials.
