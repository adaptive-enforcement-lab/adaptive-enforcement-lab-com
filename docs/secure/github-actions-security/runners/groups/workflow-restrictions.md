---
title: Workflow Restrictions
description: >-
  Configure workflow restrictions for sensitive runner groups with branch pinning, file path patterns, and repository access controls to prevent unauthorized workflow execution
---

!!! note "Pin to Specific Branches"

    Workflow restrictions must reference specific branches, not wildcards. Wildcard branch references allow attackers to create malicious branches that bypass security controls while still matching allowed workflow patterns.

## Common Misconfigurations

```text
- org/app/.github/workflows/deploy.yml@refs/heads/main
```

### Misconfiguration 4: Public Repository Access

**Problem**: Self-hosted runners accessible to public repositories.

**Risk**: External contributors submit malicious pull requests that execute on your infrastructure.

**Fix**:

```yaml
# Before (insecure)
Group: any-group
Allows public repositories: Yes

# After (secure)
Group: any-group
Allows public repositories: No
```

**Rule**: Never allow self-hosted runners for public repositories. Use GitHub-hosted runners instead.

## Troubleshooting

### Issue: Workflow Cannot Find Runners

**Symptom**: Workflow queued indefinitely with "No runners available" message.

**Causes**:

1. Repository not in runner group's allowed repositories
2. Workflow not in runner group's allowed workflows
3. Runner group visibility set to private repos but repository is public
4. Workflow specifies incorrect `runs-on` label

**Diagnosis**:

```bash
# Check repository access
gh api "/orgs/${ORG}/actions/runner-groups/${GROUP_ID}/repositories" \
  | jq -r '.repositories[].full_name' \
  | grep "your-repo"

# Check workflow restrictions
gh api "/orgs/${ORG}/actions/runner-groups/${GROUP_ID}/workflows" \
  | jq -r '.workflows[].path'
```

**Fix**:

Add repository to runner group or add workflow to allowed workflows list.

### Issue: Unauthorized Workflow Executes on Sensitive Runners

**Symptom**: Non-deployment workflow executed on production runners.

**Causes**:

1. Workflow restrictions disabled
2. Workflow added to allowed list without approval
3. Wildcard branch reference allows malicious branch

**Diagnosis**:

```bash
# Check workflow restriction status
gh api "/orgs/${ORG}/actions/runner-groups/${GROUP_ID}" \
  | jq -r '.restricted_to_workflows'
```

**Fix**:

Enable workflow restrictions and audit allowed workflows:

```bash
# Enable workflow restrictions
gh api --method PATCH \
  "/orgs/${ORG}/actions/runner-groups/${GROUP_ID}" \
  -f restricted_to_workflows=true
```

### Issue: Runner Group Configuration Drift

**Symptom**: Runner group access differs from documented configuration.

**Causes**:

1. Manual changes via Settings UI without documentation update
2. API-based changes without audit trail
3. Multiple administrators with conflicting changes

**Diagnosis**:

Compare actual configuration against documented configuration:

```bash
# Export current configuration
gh api "/orgs/${ORG}/actions/runner-groups" \
  | jq '.runner_groups[] | {name, visibility, restricted_to_workflows}' \
  > current-config.json

# Compare against documented configuration
diff current-config.json documented-config.json
```

**Fix**:

Implement configuration-as-code with CI validation:

```yaml
# .github/workflows/validate-runner-config.yml
name: Validate Runner Configuration
on:
  pull_request:
    paths:
      - .github/runner-groups.yml

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Validate configuration
        run: |
          # Validate runner group configuration matches documented state
          yamllint .github/runner-groups.yml
          # Additional validation logic
```

## Quick Reference: Runner Group Checklist

### Setup Checklist

- [ ] Create runner groups organized by trust level or workload type
- [ ] Set visibility to "Selected repositories" (not "All repositories")
- [ ] Configure repository allow-list with minimal required repositories
- [ ] Enable workflow restrictions for sensitive runner groups
- [ ] Pin allowed workflows to specific branches (refs/heads/main)
- [ ] Disable public repository access for all runner groups
- [ ] Document group purpose and access rationale
- [ ] Configure audit logging for group access changes

### Operational Checklist

- [ ] Review runner group membership quarterly
- [ ] Revoke access for deprecated repositories
- [ ] Audit workflow restrictions for compliance changes
- [ ] Monitor runner group configuration for drift
- [ ] Alert on unauthorized configuration changes
- [ ] Verify new workflows before adding to allowed list
- [ ] Test runner access with non-production workflows first
- [ ] Document approval process for runner group access

### Security Checklist

- [ ] Production runners restricted to production repositories only
- [ ] Compliance runners restricted to audited workflows only
- [ ] High-cost runners restricted to authorized teams only
- [ ] No self-hosted runners for public repositories
- [ ] Workflow restrictions enabled for all sensitive runner groups
- [ ] Branch references pinned (no wildcard refs)
- [ ] Repository access follows least privilege principle
- [ ] Audit trail configured for all runner group changes

## Next Steps

- **[Runner Security Overview](index.md)**: Understanding the self-hosted runner threat model
- **[Hardening Checklist](../hardening/index.md)**: OS-level and runtime hardening for runners
- **[Ephemeral Runners](../ephemeral/index.md)**: Disposable runner patterns for state isolation

## Related Documentation

- [Token Permissions](../../token-permissions/index.md): Scoping GITHUB_TOKEN permissions for runner jobs
- [Third-Party Actions](../../third-party-actions/index.md): Evaluating actions that execute on runners
- [Workflow Triggers](../../workflows/triggers/index.md): Understanding which events trigger runner execution
