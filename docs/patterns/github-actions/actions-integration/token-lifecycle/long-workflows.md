---
title: Long-Running Workflow Patterns
description: >-
  Error handling and patterns for long-running workflows with token expiration and refresh management.
---

## Long-Running Workflow Patterns

### Pattern 1: Multi-Phase Workflow with Token Refresh

```yaml
name: Multi-Phase Long-Running Workflow

on:
  workflow_dispatch:

jobs:
  phase-1:
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.token.outputs.token }}
    steps:
      - name: Phase 1 token
        id: token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Phase 1 operations (0-50 minutes)
        env:
          GH_TOKEN: ${{ steps.token.outputs.token }}
        run: |
          echo "Starting phase 1: $(date)"
          # Simulate long-running operations
          for i in {1..50}; do
            gh api user --jq .login
            sleep 60
          done
          echo "Completed phase 1: $(date)"

  phase-2:
    needs: phase-1
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.token.outputs.token }}
    steps:
      - name: Phase 2 token (refreshed)
        id: token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Phase 2 operations (50-100 minutes)
        env:
          GH_TOKEN: ${{ steps.token.outputs.token }}
        run: |
          echo "Starting phase 2: $(date)"
          for i in {1..50}; do
            gh api user --jq .login
            sleep 60
          done
          echo "Completed phase 2: $(date)"

  phase-3:
    needs: phase-2
    runs-on: ubuntu-latest
    steps:
      - name: Phase 3 token (refreshed again)
        id: token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ secrets.CORE_APP_ID }}
          private-key: ${{ secrets.CORE_APP_PRIVATE_KEY }}
          owner: adaptive-enforcement-lab

      - name: Phase 3 operations (100-150 minutes)
        env:
          GH_TOKEN: ${{ steps.token.outputs.token }}
        run: |
          echo "Starting phase 3: $(date)"
          for i in {1..50}; do
            gh api user --jq .login
            sleep 60
          done
          echo "Completed phase 3: $(date)"
```

### Pattern 2: Continuous Operation with Error Recovery

```yaml
name: Continuous Operation with Token Refresh

on:
  workflow_dispatch:

jobs:
  continuous-operation:
    runs-on: ubuntu-latest
    steps:
      - name: Setup token refresh function
        run: |
          cat > /tmp/refresh_token.sh << 'EOF'
          #!/bin/bash
          # Function to refresh token when needed
          refresh_token_if_needed() {
            local token_created=$1
            local current_time=$(date +%s)
            local token_age=$((current_time - token_created))
            local max_age=3300  # 55 minutes

            if [ $token_age -gt $max_age ]; then
              echo "true"
            else
              echo "false"
            fi
          }
          export -f refresh_token_if_needed
          EOF
          chmod +x /tmp/refresh_token.sh

      - name: Long-running operation with automatic refresh
        env:
          APP_ID: ${{ secrets.CORE_APP_ID }}
          PRIVATE_KEY: ${{ secrets.CORE_APP_PRIVATE_KEY }}
        run: |
          source /tmp/refresh_token.sh

          # Initial token generation
          export GH_TOKEN=$(gh api /app/installations \
            --jq '.[0].id' | xargs -I {} \
            gh api /app/installations/{}/access_tokens \
            -X POST --jq .token)
          TOKEN_CREATED=$(date +%s)

          # Continuous operation with error recovery
          ITERATION=1
          MAX_ITERATIONS=200  # ~3+ hours

          while [ $ITERATION -le $MAX_ITERATIONS ]; do
            # Check if token refresh needed
            if [ "$(refresh_token_if_needed $TOKEN_CREATED)" = "true" ]; then
              echo "::notice::Refreshing token (iteration $ITERATION)"
              export GH_TOKEN=$(gh api /app/installations \
                --jq '.[0].id' | xargs -I {} \
                gh api /app/installations/{}/access_tokens \
                -X POST --jq .token)
              TOKEN_CREATED=$(date +%s)
            fi

            # Perform operation with error recovery
            if ! gh api user --jq .login > /dev/null 2>&1; then
              echo "::warning::API call failed (iteration $ITERATION) - refreshing token"
              export GH_TOKEN=$(gh api /app/installations \
                --jq '.[0].id' | xargs -I {} \
                gh api /app/installations/{}/access_tokens \
                -X POST --jq .token)
              TOKEN_CREATED=$(date +%s)

              # Retry operation
              gh api user --jq .login
            fi

            echo "Iteration $ITERATION completed at $(date)"
            ((ITERATION++))
            sleep 60
          done
```

## Error Handling for Expired Tokens

### Detect and Recover from Expiration

```yaml
name: Token Expiration Error Handling

on:
  workflow_dispatch:

jobs:
  error-recovery:
    runs-on: ubuntu-latest
    steps:
      - name: Operation with expiration handling
        env:
          APP_ID: ${{ secrets.CORE_APP_ID }}
          PRIVATE_KEY: ${{ secrets.CORE_APP_PRIVATE_KEY }}
        run: |
          # Function to generate fresh token
          generate_token() {
            gh api /app/installations \
              --jq '.[0].id' | xargs -I {} \
              gh api /app/installations/{}/access_tokens \
              -X POST --jq .token
          }

          # Function to perform API call with retry on 401
          api_call_with_retry() {
            local max_retries=3
            local retry_count=0

            while [ $retry_count -lt $max_retries ]; do
              # Attempt API call
              if gh api user --jq .login 2>/tmp/api_error; then
                return 0
              fi

              # Check error type
              if grep -q "401" /tmp/api_error || grep -q "Bad credentials" /tmp/api_error; then
                echo "::warning::Token expired (attempt $((retry_count + 1))/$max_retries)"

                # Refresh token
                export GH_TOKEN=$(generate_token)
                echo "::notice::Token refreshed"

                ((retry_count++))
                sleep 2
              else
                # Non-expiration error - fail
                cat /tmp/api_error
                return 1
              fi
            done

            echo "::error::Failed after $max_retries retries"
            return 1
          }

          # Initial token
          export GH_TOKEN=$(generate_token)

          # Perform operations
          for i in {1..100}; do
            if ! api_call_with_retry; then
              echo "::error::Operation failed at iteration $i"
              exit 1
            fi
            sleep 60
          done
```
