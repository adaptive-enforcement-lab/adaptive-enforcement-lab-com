---
title: GitHub Apps Operations Guide
description: >-
  Troubleshooting token generation, security best practices,
  and operational patterns for GitHub Apps.
---

# GitHub Apps Operations Guide

## Migration from PATs

!!! tip "Quick Start"
    This guide is part of a modular documentation set. Refer to related guides in the navigation for complete context.

### Phase 1: Inventory

List all workflows using PATs:

```bash
grep -r "GITHUB_TOKEN\|PERSONAL_ACCESS_TOKEN" .github/workflows/
```

### Phase 2: Create Apps

Create one app per use case (releases, PRs, deployments).

### Phase 3: Update Workflows

Replace PAT references with app token generation.

### Phase 4: Revoke PATs

After migration, revoke old PATs in user settings.

### Phase 5: Document

Update runbooks to use GitHub Apps for new automation.

---

## Troubleshooting

### Error: "Resource not accessible by integration"

App lacks required permissions. Update app permissions in settings.

### Error: "Bad credentials"

Private key or App ID incorrect. Verify secrets.

### Token expires during long workflows

Generate fresh token mid-workflow:

```yaml
- name: Refresh token
  id: refresh
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.PRIVATE_KEY }}
```

---

## Related Patterns

- **[GitHub App Setup Guide](../../../operator-manual/github-actions/github-app-setup/index.md)**: Complete installation walkthrough
- **[Actions Integration](../../../operator-manual/github-actions/actions-integration/index.md)**: Workflow patterns
- **[File Distribution](../../../operator-manual/github-actions/use-cases/file-distribution/index.md)**: Cross-repo automation

---

*PATs were replaced with GitHub Apps. Token lifecycle became independent. Scope narrowed to minimum required. Auditors approved. Compliance improved.*
