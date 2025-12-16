---
title: Common Permissions
description: >-
  Permission configurations for specific automation use cases.
  File distribution, CI/CD, repository management, and security scanning.
---

# Common Permission Requirements

Permission configurations for specific automation use cases.

## File Distribution Workflows

Synchronize files across multiple repositories.

!!! abstract "Required Permissions"

    - Contents: Read & Write
    - Pull Requests: Read & Write
    - Members: Read (for team queries)

```yaml
- name: Sync configuration files
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    # Token will have Contents and PR access
```

## CI/CD Orchestration

Manage workflows and trigger runs across repositories.

!!! abstract "Required Permissions"

    - Actions: Read & Write
    - Contents: Read
    - Workflows: Write (for fork approval)

```yaml
- name: Trigger downstream workflows
  run: |
    gh workflow run deploy.yml --repo $ORG/$REPO
  env:
    GH_TOKEN: ${{ steps.token.outputs.token }}
```

## Repository Management

Create and configure repositories programmatically.

!!! abstract "Required Permissions"

    - Administration: Write
    - Contents: Read & Write
    - Members: Read

```yaml
- name: Create new repository
  run: |
    gh repo create $ORG/$NEW_REPO --private --template $ORG/template
  env:
    GH_TOKEN: ${{ steps.token.outputs.token }}
```

## Compliance Scanning

Scan repositories and create issues for findings.

!!! abstract "Required Permissions"

    - Contents: Read
    - Pull Requests: Read
    - Issues: Read & Write (for creating issues)

```yaml
- name: Create compliance issue
  run: |
    gh issue create --repo $ORG/$REPO \
      --title "Compliance Finding" \
      --body "Details of the finding..."
  env:
    GH_TOKEN: ${{ steps.token.outputs.token }}
```

## Quick Reference

| Use Case | Contents | PRs | Issues | Actions | Admin | Members |
| ---------- | :--------: | :---: | :------: | :-------: | :-----: | :-------: |
| File Distribution | R/W | R/W | - | - | - | R |
| CI/CD Orchestration | R | - | - | R/W | - | - |
| Repository Management | R/W | - | - | - | W | R |
| Compliance Scanning | R | R | R/W | - | - | - |
| Dependency Updates | R/W | R/W | - | - | - | - |
| Security Alerts | R | R | R/W | - | - | - |
| Release Management | R/W | R/W | - | R/W | - | - |

**Legend**: R = Read, W = Write, R/W = Read & Write

## Combining Permissions

For workflows that span multiple use cases:

!!! example "Multi-Purpose Automation"

    File sync + CI/CD + Compliance:

    ```text
    Contents: Read & Write
    Pull Requests: Read & Write
    Issues: Read & Write
    Actions: Read & Write
    Members: Read
    ```

!!! warning "Permission Creep"

    Regularly review combined permissions to ensure they're still necessary.

## Next Steps

- [Troubleshooting](troubleshooting.md)
- [Maintenance](maintenance.md)
