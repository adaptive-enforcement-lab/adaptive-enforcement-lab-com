---
title: Troubleshooting
description: >-
  Quick reference guide for branch protection enforcement issues. Systematic diagnosis approach with links to component-specific troubleshooting.
tags:
  - github
  - security
  - compliance
  - automation
  - operators
  - policy-enforcement
  - troubleshooting
---

# Troubleshooting

Branch protection enforcement spans multiple systems. Issues manifest differently depending on the layer.

!!! tip "Systematic Approach"
    Start with permissions. Move to API responses. Check workflow logs last. Most issues stem from authentication or scope configuration.

This guide provides quick diagnosis for common cross-cutting issues. Each component page contains detailed troubleshooting sections with complete solutions.

---

## Quick Diagnosis

**Permission denied (403 Forbidden)**: Check GitHub App has `Administration: Read & Write`. Verify installation scope includes repository. See **[GitHub Apps Setup](../../secure/github-apps/index.md)**.

**Repository not found (404)**: Repository archived, deleted, renamed, or transferred. Update configuration. Remove from Terraform state if needed.

**Rate limit exceeded**: Use GitHub App authentication (5000 req/hour vs 60 for PAT). Implement exponential backoff. Process in batches of 50.

**Webhook not triggering**: Verify webhook configured in GitHub App settings. Check delivery history. Confirm webhook secret matches workflow.

**Terraform and GitHub App conflict**: Both systems enforcing different tiers. Choose single source of truth. Use Terraform for deployment, GitHub App for drift detection only.

**False positive drift detection**: API returns `null` vs script expects empty array. Implement normalization function. Sort arrays before comparison.

**Workflow triggered but no action**: Check `repository_dispatch` payload structure. Verify dry-run mode disabled. Review workflow run logs.

**Evidence collection missing repositories**: GitHub App installation scope incomplete. Implement pagination. Include archived repositories if required for compliance.

**Bypass request denied**: Approver not member of required team. Verify approval label applied. Check workflow permissions.

**Protection not restored after bypass**: Auto-restore workflow not scheduled. Backup file missing. Verify time zone handling (use UTC consistently).

**Exception approved but drift detected**: Exception not recorded in database. Drift detection not checking exception database before flagging.

**Historical evidence not found**: Evidence collection started after target date. Check retention policy. Verify filename pattern matches query.

**Compliance report shows failures**: Historical query showing past state, not current. Verify tier assignment. Document compensating controls for exceptions.

**Workflow timeout (>6 hours)**: Too many repositories. Implement pagination. Process in batches. Use parallel processing with thread pools.

---

## Common Patterns by Category

### GitHub API and Permissions

Most enforcement issues stem from authentication or scope.

Verify GitHub App permissions with `gh api apps/APP_SLUG/installations/INSTALLATION_ID`. Check repository installation scope. Verify organization security settings.

Check rate limits before bulk operations. Use GitHub App authentication (5000 req/hour). Implement exponential backoff. Process repositories in batches.

See **[GitHub App Enforcement](github-app-enforcement.md)** troubleshooting section for webhook configuration, permission issues, and remediation loops.

---

### Terraform and IaC Issues

**State file too large**: Split into per-tier workspaces or implement dynamic generation. Use `terraform apply -target` for incremental applies.

**Remediation loop**: Terraform and GitHub App enforce different configurations. Disable GitHub App remediation (detection only) or remove Terraform management.

**Import existing protection**: Use `terraform import 'module.repo_protection.github_branch_protection.main' 'org/repo:main'` before managing existing protection.

**Repository not found**: Remove deleted repositories from Terraform state with `terraform state rm 'module.repo_protection["deleted-repo"]'`.


---

### Drift Detection and Remediation

**False positives**: Implement normalization function to handle API format variations (null vs empty array, boolean vs string, unordered arrays).

**Detection logic incomplete**: Add comprehensive field coverage for all protection settings including reviews, status checks, admin enforcement, linear history, signatures.

**Continuous drift alerts**: Exception approved but not in database, or drift detection not checking exception database before flagging.

See **[Drift Detection](drift-detection.md)** troubleshooting section for normalization patterns and detection accuracy.

---

### Webhook and Workflow Issues

**Webhook not configured**: Verify webhook URL, events (`branch_protection_rule`), and secret in GitHub App settings. Check delivery history.

**Workflow triggered but no action**: Verify `repository_dispatch` payload structure. Check conditional logic. Confirm dry-run mode disabled.

**Workflow timeout**: Paginate API calls (100 per page). Process in batches of 50. Use parallel processing. Increase timeout (`timeout-minutes: 360`).

**Permission denied in workflow**: Verify GitHub App token permissions. Check installation scope.

See **[Enforcement Workflows](enforcement-workflows.md)** troubleshooting section for workflow debugging.

---

### Audit and Compliance

**Evidence collection missing repositories**: GitHub App installation scope incomplete. Implement pagination. Include archived repositories if required.

**Historical verification finds no evidence**: Evidence collection started after target date. Check retention policy (7 years SOC 2/PCI-DSS). Verify filename pattern.

**Compliance report shows non-compliant**: Historical query showing past state. Verify tier assignment. Check if recent changes not yet reflected.

**Report generation timeout**: Split by framework. Paginate queries. Process in batches for large organizations.

See **[Audit Evidence](audit-evidence.md)**, **[Compliance Reporting](compliance-reporting.md)**, and **[Verification Scripts](verification-scripts.md)** troubleshooting sections.

---

### Bypass and Emergency Access

**Bypass request denied**: Approver not member of required team. Verify approval label applied correctly. Check issue template fields complete.

**Protection not restored**: Auto-restore workflow not scheduled. Backup file missing or corrupted. Time zone calculation incorrect (use UTC consistently).

**Break-glass blocked**: Incident ticket validation failed. Severity level insufficient (must be "high" or "critical"). Integration with incident system broken.

**Exception not recognized**: Exception approved but not recorded in database. Drift detection not checking exception database.

See **[Bypass Controls](bypass-controls.md)**, **[Emergency Access](emergency-access.md)**, and **[Exception Management](exception-management.md)** troubleshooting sections.

---

## Edge Cases

**Protected branch renamed**: Remove old branch from Terraform state. Import protection for new branch name. Update configuration references.

**Repository transferred between organizations**: Remove from old organization state. Import in new organization. Verify GitHub App installed in new org.

**Force push blocked despite bypass approval**: Organization rulesets override branch protection. Check organization-level rulesets. Temporarily disable for emergency access.

**New repositories inherit no protection**: No webhook for repository creation. Template repository has no protection. Configure `repository.created` webhook to apply default Standard tier.

**Protection removed but detection passes**: Detection logic doesn't cover all fields. Add comprehensive field checking. Test against known configurations.

**Terraform detects drift on first run**: Existing protection not imported. Run `terraform import` before first apply to establish baseline.

See component-specific troubleshooting sections for detailed resolution steps.

---

## Debugging Best Practices

**1. Enable debug logging**: Set `ACTIONS_STEP_DEBUG=true` in workflow environment for detailed logs.

**2. Use dry-run mode**: Test changes without applying. Terraform: `terraform plan`. Workflows: `DRY_RUN=true ./script.sh`.

**3. Verify permissions first**: 90% of issues stem from missing permissions or scope. Check GitHub App installation and permissions.

**4. Check raw API responses**: Use `gh api repos/ORG/REPO/branches/main/protection` to see actual configuration vs expected.

**5. Review workflow run logs**: Complete execution history in Actions tab. Use `gh run list` and `gh run view RUN_ID --log`.

**6. Test with canary repositories**: Validate changes on non-production repositories before organization-wide rollout.

**7. Isolate variables**: When troubleshooting, simplify configuration to isolate root cause. Test single repository before bulk operations.

**8. Check GitHub API status**: Verify GitHub API operational at `https://www.githubstatus.com` before debugging infrastructure.

**9. Monitor rate limits**: Check remaining requests with `gh api rate_limit` before bulk operations.

**10. Use systematic elimination**: Permissions → API responses → webhook configuration → workflow logic → script logic.

---

## Component-Specific Troubleshooting

Each pattern page contains dedicated troubleshooting section with detailed solutions:

### Configuration and Standards

- **[Security Tiers](security-tiers.md)**: Tier configuration, selection, and migration

### Infrastructure as Code

- **[OpenTofu Modules](opentofu-modules.md)**: OpenTofu-specific issues and state encryption
- **[Multi-Repo Management](multi-repo-management.md)**: Organization-wide operations, bulk updates, staging

### GitHub App Enforcement

- **[GitHub App Enforcement](github-app-enforcement.md)**: App permissions, webhooks, remediation loops
- **[Enforcement Workflows](enforcement-workflows.md)**: Workflow debugging, payload structure, timeouts
- **[Drift Detection](drift-detection.md)**: False positives, normalization, detection accuracy

### Audit and Compliance

- **[Audit Evidence](audit-evidence.md)**: Evidence collection, storage, integrity verification
- **[Compliance Reporting](compliance-reporting.md)**: Framework reports, SOC 2, ISO 27001, PCI-DSS
- **[Verification Scripts](verification-scripts.md)**: Script debugging, historical verification

### Bypass Controls

- **[Bypass Controls](bypass-controls.md)**: Bypass approval, time-boxing, restoration
- **[Emergency Access](emergency-access.md)**: Break-glass procedures, incident validation
- **[Exception Management](exception-management.md)**: Exception tracking, review workflows

---

## Getting Additional Help

If issue not covered:

1. **Check component-specific troubleshooting section** for detailed solutions
2. **Review workflow run logs** for complete error context (Actions tab)
3. **Verify GitHub API status** at `https://www.githubstatus.com`
4. **Check rate limits** with `gh api rate_limit`
5. **Test with simplified configuration** to isolate variables
6. **Enable debug logging** (`ACTIONS_STEP_DEBUG=true`) for verbose output
7. **Use dry-run mode** to test changes safely
8. **Verify permissions** as first troubleshooting step

---

*The error was encountered. Logs were reviewed. Root cause identified. Solution applied. Protection restored. Compliance maintained. The system self-healed.*
