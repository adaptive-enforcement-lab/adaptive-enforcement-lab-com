---
title: Error Handling
description: >-
  Handle token generation failures, API rate limits, and permission errors
  gracefully.
---

# Error Handling

!!! danger "Don't Fail Silently"
    Always check for failures and provide actionable error messages. Silent failures waste hours of debugging.

## Handle Token Generation Failures

```yaml
- name: Generate token
  id: app_token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ secrets.CORE_APP_ID }}
    private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
    owner: your-org
  continue-on-error: true

- name: Check token generation
  if: steps.app_token.outcome == 'failure'
  run: |
    echo "Token generation failed"
    echo "Check: App ID, Private Key, and App installation"
    exit 1
```

## Handle API Rate Limits

```yaml
- name: API call with retry
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    MAX_RETRIES=3
    RETRY_DELAY=60

    for i in $(seq 1 $MAX_RETRIES); do
      if gh api /orgs/your-org/repos; then
        exit 0
      fi

      echo "Retry $i/$MAX_RETRIES after ${RETRY_DELAY}s"
      sleep $RETRY_DELAY
    done

    echo "Failed after $MAX_RETRIES retries"
    exit 1
```

## Handle Permission Errors

```yaml
- name: Operation with permission check
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    if ! gh api /repos/your-org/repo/collaborators 2>&1 | grep -q "403"; then
      echo "Has required permissions"
      gh api /repos/your-org/repo/collaborators
    else
      echo "Missing permissions - check app configuration"
      exit 1
    fi
```
