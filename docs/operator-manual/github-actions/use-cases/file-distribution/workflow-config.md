---
title: Workflow Configuration
description: >-
  Trigger configuration and required permissions.
---

# Workflow Configuration

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
|----------|-------------|--------|
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
