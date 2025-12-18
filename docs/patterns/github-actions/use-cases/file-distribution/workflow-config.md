---
title: Workflow Configuration
description: >-
  Configure distribution triggers, permissions, and scheduled coverage runs. Catch new repositories and failed runs with weekend schedules and idempotent patterns.
---

# Workflow Configuration

!!! abstract "Configuration Reference"
    Triggers, permissions, and environment variables for file distribution workflows.

## Trigger Configuration

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'source-file.txt'  # Only trigger when this file changes
  workflow_dispatch:  # Allow manual triggers
```

## Required Permissions

```yaml
permissions:
  contents: write  # For checking out and pushing to repositories
  id-token: write  # For generating Core App tokens
  pull-requests: write  # For creating pull requests
```

## Complete Workflow Template

```yaml
name: Distribute Files

on:
  push:
    branches:
      - main
    paths:
      - 'source-file.txt'
  workflow_dispatch:

permissions:
  contents: write
  id-token: write
  pull-requests: write

jobs:
  discover:
    # See discovery-stage.md

  distribute:
    # See distribution-stage.md

  summary:
    # See summary-stage.md
```

## Environment Variables

| Variable | Description | Source |
| ---------- | ------------- | -------- |
| `CORE_APP_ID` | GitHub App ID | Repository secret |
| `CORE_APP_PRIVATE_KEY` | GitHub App private key | Repository secret |
| `GH_TOKEN` | Generated token | Workflow step output |

## Manual Trigger Options

Add inputs for manual workflow dispatch:

```yaml
on:
  workflow_dispatch:
    inputs:
      dry_run:
        description: 'Skip PR creation'
        required: false
        default: 'false'
        type: boolean
      target_team:
        description: 'Team slug to target'
        required: false
        default: 'default-team'
        type: string
```

---

## Scheduled Coverage Runs

Push-triggered workflows miss edge cases:

- **New repositories** added after the last distribution
- **Failed runs** that weren't retried
- **Manual changes** that bypassed automation

Add scheduled runs to catch these:

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'CONTRIBUTING.md'
  schedule:
    # Run every Saturday and Sunday at 06:00 UTC
    - cron: '0 6 * * 6,0'
  workflow_dispatch:
```

### Cron Syntax

Format: `minute hour day-of-month month day-of-week`

| Pattern | Schedule |
| --------- | ---------- |
| `0 6 * * 6,0` | Saturdays and Sundays at 06:00 UTC |
| `0 0 * * 1` | Mondays at midnight UTC |
| `0 */6 * * *` | Every 6 hours |
| `0 9 1 * *` | First day of each month at 09:00 UTC |

### Why Weekends?

Weekend schedules provide:

1. **Low-traffic timing** - Fewer competing workflows
2. **Catch-up window** - New repos added during the week
3. **Non-disruptive** - PRs created before Monday review

### Idempotency Matters

Scheduled runs process all repositories, even those already up-to-date. The workflow must be [idempotent](idempotency.md):

- Skip repositories with no changes
- Skip repositories with existing PRs
- Only create work where needed

Without idempotency, scheduled runs create duplicate PRs.

---

## Related

- [Idempotency](idempotency.md) - Safe re-execution guarantees
- [Discovery Stage](discovery-stage.md) - Repository discovery and filtering
- [GitHub Actions: Scheduled Events](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule) - Cron syntax reference
