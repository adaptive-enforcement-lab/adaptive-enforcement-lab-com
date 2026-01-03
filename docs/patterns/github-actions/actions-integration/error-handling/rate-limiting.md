---
title: Rate Limiting Error Handling
description: >-
  Handle rate limiting (429) and validation errors (422) in GitHub Actions workflows. Exponential backoff and retry patterns.
---

## Rate Limiting (429 Errors)

### Rate Limit Detection and Headers

```yaml
- name: API call with rate limit awareness
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    # Make API call and capture headers
    response=$(gh api user -i 2>&1)

    # Extract rate limit headers
    remaining=$(echo "$response" | grep -i "x-ratelimit-remaining:" | awk '{print $2}' | tr -d '\r')
    reset=$(echo "$response" | grep -i "x-ratelimit-reset:" | awk '{print $2}' | tr -d '\r')

    echo "Rate limit remaining: $remaining"

    if [ "$remaining" -lt 100 ]; then
      reset_time=$(date -r "$reset" 2>/dev/null || date -d "@$reset" 2>/dev/null)
      echo "::warning::Low rate limit: $remaining requests remaining"
      echo "::warning::Resets at: $reset_time"
    fi
```

### Exponential Backoff Retry

```yaml
- name: API call with exponential backoff
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    # API call with exponential backoff
    api_call_with_backoff() {
      local endpoint="$1"
      local max_retries=5
      local retry=0
      local base_delay=1

      while [ $retry -lt $max_retries ]; do
        # Attempt API call
        if response=$(gh api "$endpoint" 2>&1); then
          echo "$response"
          return 0
        fi

        # Check if rate limited
        if echo "$response" | grep -q "429\|rate limit"; then
          # Calculate exponential backoff: 2^retry * base_delay
          delay=$((base_delay * (2 ** retry)))

          echo "::warning::Rate limited (attempt $((retry + 1))/$max_retries)"
          echo "::warning::Waiting ${delay}s before retry"

          sleep "$delay"
          ((retry++))
        else
          # Non-rate-limit error
          echo "::error::API call failed: $response"
          return 1
        fi
      done

      echo "::error::Failed after $max_retries retries"
      return 1
    }

    # Make API call
    api_call_with_backoff "orgs/adaptive-enforcement-lab/repos"
```

**Backoff progression**:

| Retry | Delay |
|-------|-------|
| 1 | 1s |
| 2 | 2s |
| 3 | 4s |
| 4 | 8s |
| 5 | 16s |

### Wait for Rate Limit Reset

```yaml
- name: API call with rate limit wait
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    api_call_with_wait() {
      local endpoint="$1"

      # Attempt API call with header capture
      response=$(gh api "$endpoint" -i 2>&1)

      # Check for rate limit
      if echo "$response" | grep -q "429"; then
        # Extract reset time from headers
        reset=$(echo "$response" | grep -i "x-ratelimit-reset:" | awk '{print $2}' | tr -d '\r')
        now=$(date +%s)
        wait_time=$((reset - now + 1))

        if [ $wait_time -gt 0 ] && [ $wait_time -lt 3600 ]; then
          echo "::warning::Rate limited. Waiting ${wait_time}s for reset"
          sleep "$wait_time"

          # Retry after reset
          gh api "$endpoint"
        else
          echo "::error::Rate limit reset time invalid or too far in future"
          return 1
        fi
      else
        # Not rate limited - extract body
        echo "$response" | sed -n '/^$/,$p' | tail -n +2
      fi
    }

    api_call_with_wait "user"
```

!!! tip "Rate Limit Optimization"

    - Use GraphQL for complex queries (single request vs multiple REST calls)
    - Cache responses when possible
    - Share tokens across concurrent jobs to pool rate limits
    - Monitor `x-ratelimit-remaining` header proactively

## Validation Errors (422 Unprocessable Entity)

### Handle Invalid Requests

```yaml
- name: Create issue with validation
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    # Create issue payload
    payload=$(cat <<EOF
    {
      "title": "Automated issue",
      "body": "This is an automated issue",
      "labels": ["automation", "bug"]
    }
    EOF
    )

    # Attempt creation with error handling
    if ! response=$(gh api "/repos/adaptive-enforcement-lab/example-repo/issues" \
                      -X POST \
                      --input - <<< "$payload" 2>&1); then

      if echo "$response" | grep -q "422"; then
        echo "::error::Validation failed"
        echo "::error::Payload: $payload"
        echo "::error::Response: $response"
        echo "::error::Common causes:"
        echo "  - Invalid label names"
        echo "  - Required fields missing"
        echo "  - Field value exceeds maximum length"
        exit 1
      else
        echo "::error::Request failed: $response"
        exit 1
      fi
    fi

    echo "Issue created: $(echo "$response" | jq -r .html_url)"
```

### Validate Before API Call

```yaml
- name: Create PR with pre-validation
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    REPO="adaptive-enforcement-lab/example-repo"
    HEAD_BRANCH="feature/new-feature"
    BASE_BRANCH="main"

    # Validate branches exist
    if ! gh api "/repos/$REPO/git/ref/heads/$HEAD_BRANCH" &>/dev/null; then
      echo "::error::Head branch '$HEAD_BRANCH' does not exist"
      exit 1
    fi

    if ! gh api "/repos/$REPO/git/ref/heads/$BASE_BRANCH" &>/dev/null; then
      echo "::error::Base branch '$BASE_BRANCH' does not exist"
      exit 1
    fi

    # Validate no existing PR
    existing=$(gh api "/repos/$REPO/pulls?head=$HEAD_BRANCH&base=$BASE_BRANCH" --jq 'length')
    if [ "$existing" -gt 0 ]; then
      echo "::error::PR already exists for $HEAD_BRANCH -> $BASE_BRANCH"
      exit 1
    fi

    # Create PR
    gh api "/repos/$REPO/pulls" -X POST -f title="New Feature" \
      -f head="$HEAD_BRANCH" -f base="$BASE_BRANCH" -f body="Automated PR"
```

## Network and Server Errors (5xx)

### Retry Transient Failures

```yaml
- name: API call with transient error retry
  env:
    GH_TOKEN: ${{ steps.app_token.outputs.token }}
  run: |
    api_call_with_retry() {
      local endpoint="$1"
      local max_retries=3
      local retry_delay=5
      local retry=0

      while [ $retry -le $max_retries ]; do
        # Attempt API call
        if response=$(gh api "$endpoint" 2>&1); then
          echo "$response"
          return 0
        fi

        # Check for server errors (5xx) or network issues
        if echo "$response" | grep -qE "50[0-9]|timeout|connection"; then
          if [ $retry -lt $max_retries ]; then
            echo "::warning::Transient error (attempt $((retry + 1))/$((max_retries + 1)))"
            echo "::warning::Error: $response"
            echo "::warning::Retrying in ${retry_delay}s"

            sleep "$retry_delay"
            ((retry++))
          else
            echo "::error::Failed after $((max_retries + 1)) attempts"
            echo "::error::Last error: $response"
            return 1
          fi
        else
          # Non-transient error
          echo "::error::API call failed: $response"
          return 1
        fi
      done
    }

    api_call_with_retry "user"
```
