---
title: Supporting Scripts
description: >-
  Extract branch management into reusable scripts. Implement idempotent branch preparation with force reset, remote state handling, and git credential automation.
---

# Supporting Scripts

!!! abstract "Reusable Components"
    Extract branch management and authentication into scripts. Keeps workflow YAML readable and enables testing.

## Branch Preparation Script

Create `scripts/prepare-branch.sh` for idempotent branch management:

```bash
#!/bin/bash
set -e

# Usage: prepare-branch.sh <branch_name> <default_branch>

BRANCH_NAME="$1"
DEFAULT_BRANCH="$2"

if [ -z "$BRANCH_NAME" ] || [ -z "$DEFAULT_BRANCH" ]; then
  echo "Usage: $0 <branch_name> <default_branch>"
  exit 1
fi

# Configure git authentication
if [ -n "$GH_TOKEN" ]; then
  git config --local credential.helper \
    '!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f'
fi

git fetch origin

if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
  echo "Branch exists remotely, resetting to remote state..."
  git checkout -B "$BRANCH_NAME" "origin/$BRANCH_NAME"
elif git branch --list "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
  echo "Branch exists locally, checking out..."
  git checkout "$BRANCH_NAME"
else
  echo "Creating new branch from $DEFAULT_BRANCH..."
  git checkout -b "$BRANCH_NAME"
fi
```

## Script Features

**Idempotency**: Uses `git checkout -B` to force reset to remote state, avoiding merge conflicts on subsequent runs.

## Git Authentication

The script automatically configures git credentials when `GH_TOKEN` is set:

```bash
git config --local credential.helper \
  '!f() { echo "username=x-access-token"; echo "password=$GH_TOKEN"; }; f'
```

This allows push operations to use the GitHub App token.

## Branch State Handling

| Scenario | Action |
| ---------- | -------- |
| Branch exists remotely | Reset to remote state |
| Branch exists locally only | Checkout local branch |
| Branch doesn't exist | Create from default branch |
