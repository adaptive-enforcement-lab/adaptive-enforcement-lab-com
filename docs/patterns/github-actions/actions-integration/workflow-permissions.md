---
title: Workflow Permissions
description: >-
  Configure workflow-level and job-level permissions for GitHub App token generation. Explicit id-token write and contents read for secure Actions automation.
---

# Workflow Permissions

!!! warning "Explicit Permissions Required"
    Workflows with restricted permissions must declare `id-token: write` for Core App token generation.

## Required Workflow Permissions

Declare minimum permissions for workflows using Core App tokens:

```yaml
name: Example Workflow

on:
  push:
    branches: [main]

permissions:
  contents: read  # For checking out code
  id-token: write  # For generating Core App tokens

jobs:
  example:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate token
        id: app_token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org
```

**Key Permissions**:

- `contents: read` - Required for checkout action
- `id-token: write` - Required for generating app tokens

## Job-Level vs Workflow-Level Permissions

```yaml
# Workflow-level (applies to all jobs)
permissions:
  contents: read
  id-token: write

jobs:
  job1:
    runs-on: ubuntu-latest
    # Inherits workflow permissions

  job2:
    runs-on: ubuntu-latest
    permissions:
      # Override for this job only
      contents: write
      id-token: write
```
