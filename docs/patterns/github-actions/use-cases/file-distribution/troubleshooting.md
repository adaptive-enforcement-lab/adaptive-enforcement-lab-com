---
title: Troubleshooting
description: >-
  Common issues and solutions for file distribution workflows.
---

# Troubleshooting

!!! tip "Debug Workflow"
    Use the debug workflow at the bottom of this page to systematically verify token scope, org access, and team queries.

## Common Issues

### No Repositories Found

**Symptom**: Discovery returns 0 repositories

**Checks**:

1. Verify team slug is correct
2. Confirm Core App has "Members" organization permission
3. Check `owner` parameter in token generation

```bash
# Debug: Test team query directly
gh api graphql -f query='
{
  organization(login: "your-org") {
    team(slug: "target-team") {
      name
      repositories(first: 5) {
        totalCount
        nodes { name }
      }
    }
  }
}'
```

### PRs Not Created

**Symptom**: Workflow completes but no PRs appear

**Checks**:

1. Verify files actually changed
2. Check change detection logic
3. Review workflow logs for error messages

```yaml
# Add debug output
- name: Debug changes
  working-directory: target
  run: |
    echo "Git status:"
    git status
    echo "Git diff:"
    git diff
```

### New Files Not Detected

**Symptom**: Distribution reports "No changes needed" for repos missing the file

**Root Cause**: Using `git diff --quiet` instead of `git status --porcelain`

`git diff` only detects modifications to **tracked files**. When distributing a file
to a repository that doesn't have it yet, the file is **untracked** and invisible
to `git diff`.

**Solution**: Use `git status --porcelain` for change detection:

```bash
# Wrong - misses untracked files
if git diff --quiet; then
  echo "No changes"
fi

# Correct - detects all changes including new files
if [ -z "$(git status --porcelain)" ]; then
  echo "No changes"
fi
```

See [Change Detection](idempotency.md#change_detection) for the full pattern.

### Permission Denied

**Symptom**: `403 Forbidden` errors

**Checks**:

1. Verify Core App has required permissions
2. Confirm app installed on target repositories
3. Check workflow permissions declaration

### Rate Limiting

**Symptom**: `403 Rate limit exceeded` errors

**Solution**:

1. Reduce `max-parallel` value
2. Add rate limit checking
3. Implement exponential backoff

```bash
# Check current rate limit
gh api /rate_limit --jq '.resources.core'
```

### Branch Conflicts

**Symptom**: Push fails with "non-fast-forward" error

**Solution**: Ensure branch preparation script uses force reset:

```bash
git checkout -B "$BRANCH_NAME" "origin/$BRANCH_NAME"
```

### Clone Failures

**Symptom**: `Repository not found` errors

**Checks**:

1. Verify repository exists
2. Confirm Core App installed on repository
3. Check repository visibility settings

## Debug Workflow

```yaml
name: Debug File Distribution
on:
  workflow_dispatch:

jobs:
  debug:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: auth
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: your-org

      - name: Test token
        env:
          GH_TOKEN: ${{ steps.auth.outputs.token }}
        run: |
          echo "=== Rate Limits ==="
          gh api /rate_limit --jq '.resources.core'

          echo "=== Org Access ==="
          gh api /orgs/your-org --jq '{name, login}'

          echo "=== Team Query ==="
          gh api graphql -f query='
          {
            organization(login: "your-org") {
              teams(first: 5) {
                nodes { name, slug }
              }
            }
          }' --jq '.data.organization.teams'

          echo "=== App Installation ==="
          gh api /orgs/your-org/installations --jq '.installations[] | {id, app_slug}'
```

## Error Reference

| Error | Cause | Solution |
| ------- | ------- | ---------- |
| `404 Not Found` | Repo doesn't exist or no access | Check installation scope |
| `403 Forbidden` | Insufficient permissions | Review app permissions |
| `422 Unprocessable` | Invalid PR parameters | Check base/head branch names |
| `409 Conflict` | Branch already exists differently | Use force reset in script |
| `502 Bad Gateway` | GitHub temporary issue | Retry with backoff |
